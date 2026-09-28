import AppKit
import Observation

/// Shows system notifications in the island as they arrive.
///
/// macOS offers no public API to observe other apps' notifications, so Halo reads
/// Notification Center's own database (Full Disk Access required) and posts a banner for
/// each new record. The system banner still appears too; Halo only mirrors it.
@MainActor
@Observable
final class NotificationMirror {
    enum Status: Equatable {
        case off
        case needsFullDiskAccess
        case unavailable(String)
        case running
    }

    private(set) var status: Status = .off
    private(set) var isEnabled = Preferences.notificationsEnabled

    @ObservationIgnored private let alerts: AlertCenter
    @ObservationIgnored private let databaseURL = NotificationDatabase.defaultURL
    @ObservationIgnored private var database: NotificationDatabase?
    @ObservationIgnored private var watcher: DatabaseChangeWatcher?
    @ObservationIgnored private var lastID: Int64 = 0
    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    /// More new records than this at once (e.g. after waking) shows only the newest.
    static let burstLimit = 3

    init(alerts: AlertCenter) {
        self.alerts = alerts
    }

    func start() {
        guard isEnabled, status != .running else { return }
        do {
            let database = try NotificationDatabase(url: databaseURL)
            lastID = try database.latestID()
            self.database = database
        } catch {
            fail(error)
            return
        }
        let watcher = DatabaseChangeWatcher(databaseURL: databaseURL) { [weak self] in
            self?.databaseChanged()
        }
        watcher.start()
        self.watcher = watcher
        stopWaitingForAccess()
        status = .running
        Log.app.info("notification mirroring started")
    }

    func stop() {
        watcher?.stop()
        watcher = nil
        database = nil
        stopWaitingForAccess()
        status = .off
        alerts.withdraw(.notification)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.notificationsEnabled = enabled
        if enabled { start() } else { stop() }
    }

    /// Retries after the user may have granted Full Disk Access (menu opened, app switch).
    func refreshAccess() {
        guard isEnabled, status != .running else { return }
        start()
    }

    func openFullDiskAccessSettings() {
        let pane = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        if let url = URL(string: pane) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Records

    private func databaseChanged() {
        guard let database else { return }
        let records: [NotificationRecord]
        do {
            records = try database.records(after: lastID, limit: 50)
        } catch {
            Log.app.error("notification read failed: \(String(describing: error), privacy: .public)")
            return
        }
        guard let newest = records.last else { return }
        lastID = newest.id

        let shown = records.count > Self.burstLimit ? [newest] : records
        for record in shown {
            if let alert = Self.alert(for: record) {
                alerts.post(.notification(alert))
            }
        }
    }

    private static func alert(for record: NotificationRecord) -> NotificationAlert? {
        guard record.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
        let payload = NotificationPayload.parse(record.data) ?? NotificationPayload()
        let appName = applicationName(for: record.bundleIdentifier)
        return NotificationAlert(
            id: record.id,
            bundleIdentifier: record.bundleIdentifier,
            appName: appName,
            title: payload.title ?? appName,
            body: payload.message
        )
    }

    private static func applicationName(for bundleIdentifier: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return bundleIdentifier
        }
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    // MARK: Access

    private func fail(_ error: Error) {
        switch error as? NotificationDatabase.OpenError {
        case .permissionDenied:
            status = .needsFullDiskAccess
            waitForAccess()
        case .notFound:
            status = .unavailable("Database delle notifiche non trovato")
        case .sqlite(let message):
            status = .unavailable(message)
        case nil:
            status = .unavailable(error.localizedDescription)
        }
        Log.app.info("notification mirroring unavailable: \(String(describing: error), privacy: .public)")
    }

    /// There is no notification for a Full Disk Access grant; retry whenever the user
    /// switches app (for example back from System Settings). Event driven, no polling.
    private func waitForAccess() {
        guard activationObserver == nil else { return }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshAccess()
            }
        }
    }

    private func stopWaitingForAccess() {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        activationObserver = nil
    }
}
