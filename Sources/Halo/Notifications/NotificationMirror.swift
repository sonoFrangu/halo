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
    /// Whether a Focus is silencing notifications now; apps allowed through still show.
    @ObservationIgnored var isFocusSilencing: () -> Bool = { false }

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

    /// Apps registered with Notification Center, for the per-app list in Settings.
    /// Empty while mirroring is off or Full Disk Access is missing.
    func appIdentifiers() -> [String] {
        guard let database else { return [] }
        do {
            return try database.appIdentifiers()
        } catch {
            Log.app.error("notification apps read failed: \(String(describing: error), privacy: .public)")
            return []
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
        let focusSilencing = isFocusSilencing()
        let shown = records.count > Self.burstLimit ? [newest] : records
        for record in shown {
            let decision = NotificationRules.decide(
                bundleIdentifier: record.bundleIdentifier,
                ownBundleIdentifier: Bundle.main.bundleIdentifier,
                mode: Preferences.notificationMode(for: record.bundleIdentifier),
                focusSilencing: focusSilencing,
                bypassesFocus: Preferences.bypassesFocus(record.bundleIdentifier)
            )
            guard let alert = Self.alert(for: record, decision: decision) else { continue }
            guard let imageURL = alert.imageURL else {
                alerts.post(.notification(alert))
                continue
            }
            // The banner reads the thumbnail synchronously, so it is made before posting.
            Task { [weak self] in
                _ = await NotificationThumbnail.load(alert.id, from: imageURL)
                self?.alerts.post(.notification(alert))
            }
        }
    }

    private static func alert(for record: NotificationRecord, decision: NotificationDecision) -> NotificationAlert? {
        let appName = AppName.of(record.bundleIdentifier)
        switch decision {
        case .drop:
            return nil
        case .appOnly:
            // No title or body: the banner shows the app's name only, and no photo.
            return NotificationAlert(
                id: record.id,
                bundleIdentifier: record.bundleIdentifier,
                text: NotificationText.make(title: nil, subtitle: nil, body: nil, appName: appName),
                imageURL: nil
            )
        case .full:
            let payload = NotificationPayload.parse(record.data) ?? NotificationPayload()
            return NotificationAlert(
                id: record.id,
                bundleIdentifier: record.bundleIdentifier,
                text: NotificationText.make(
                    title: payload.title,
                    subtitle: payload.subtitle,
                    body: payload.body,
                    appName: appName
                ),
                imageURL: payload.imageURL
            )
        }
    }

    /// Web push from a website (Safari lists each site as `_WEB_CENTER_:web.<reversed
    /// domain>`): never mirrored, since that is where fake "your Mac is infected" alerts
    /// come from. Notifications of real apps are.
    nonisolated static func isFromWebsite(_ bundleIdentifier: String) -> Bool {
        bundleIdentifier.hasPrefix("_WEB_CENTER_")
    }

    /// macOS's own Bluetooth banners ("AirPods connected", with batteries): never mirrored,
    /// since `AudioDeviceMonitor` already shows headphones in the island.
    nonisolated static func isFromBluetooth(_ bundleIdentifier: String) -> Bool {
        let identifier = bundleIdentifier.lowercased()
        return identifier.hasPrefix("com.apple.bluetooth") || identifier.hasPrefix("_system_center_:com.apple.bluetooth")
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
