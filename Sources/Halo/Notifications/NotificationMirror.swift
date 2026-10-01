import AppKit
import Observation

/// Shows system notifications in the island as they arrive.
///
/// macOS offers no public API to observe other apps' notifications, so Halo reads
/// Notification Center's own database (Full Disk Access required) and posts a banner for
/// each new record. The system banner still appears too; Halo only mirrors it.
///
/// A record is written only when its system banner leaves the screen, about five seconds
/// late, so with Accessibility the banner itself is read the moment it appears
/// (`SystemBannerWatcher`) and the record then only brings the photo, or a notification
/// whose banner was not read (no Accessibility, an app name Halo cannot match).
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
    @ObservationIgnored private var banners: SystemBannerWatcher?
    /// Notifications shown from their banner, waiting for their database record.
    @ObservationIgnored private var shownFromBanners: [(alert: NotificationAlert, date: Date)] = []
    @ObservationIgnored private var nextBannerID: Int64 = -1
    /// Whether a Focus is silencing notifications now; apps allowed through still show.
    @ObservationIgnored var isFocusSilencing: () -> Bool = { false }

    /// More new records than this at once that no banner showed (e.g. after waking) shows
    /// only the newest.
    static let burstLimit = 3
    /// How long a notification shown from its banner waits for its record. A banner kept
    /// on screen (pointer on it, alert style) delays the record.
    static let recordWait: TimeInterval = 600

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
        let banners = SystemBannerWatcher { [weak self] banner in
            self?.bannerAppeared(banner)
        }
        banners.start()
        self.banners = banners
        stopWaitingForAccess()
        status = .running
        Log.app.info("notification mirroring started")
    }

    func stop() {
        watcher?.stop()
        watcher = nil
        banners?.stop()
        banners = nil
        shownFromBanners.removeAll()
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
        Log.app.debug("notification records read: \(records.count)")
        guard let newest = records.last else { return }
        lastID = newest.id
        var unseen: [NotificationAlert] = []
        for record in records {
            let payload = NotificationPayload.parse(record.data) ?? NotificationPayload()
            guard let alert = alert(
                id: record.id,
                bundleIdentifier: record.bundleIdentifier,
                title: payload.title,
                subtitle: payload.subtitle,
                body: payload.body,
                imageURL: payload.imageURL
            ) else { continue }
            if takeShownFromBanner(alert) {
                Log.app.debug("notification record matched its banner")
                // Already on screen from its banner: only its photo is new.
                if let imageURL = alert.imageURL {
                    Task { [weak self] in
                        _ = await NotificationThumbnail.load(alert.id, from: imageURL)
                        self?.alerts.refresh(.notification(alert))
                    }
                }
                continue
            }
            if shownFromBanners.contains(where: { $0.alert.bundleIdentifier == alert.bundleIdentifier }) {
                // Notification Center shows about one banner a second per app and folds
                // the rest into it: count it on the banner already shown, never late alone.
                Log.app.debug("notification record folded into a banner")
                alerts.fold(.notification(alert))
                continue
            }
            unseen.append(alert)
        }
        for alert in unseen.count > Self.burstLimit ? Array(unseen.suffix(1)) : unseen {
            Log.app.debug("notification shown from its record: \(alert.bundleIdentifier, privacy: .public)")
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

    // MARK: Banners

    private func bannerAppeared(_ banner: SystemBanner) {
        guard let bundleIdentifier = bundleIdentifier(ofAppNamed: banner.appName) else {
            Log.app.debug("notification banner of an unknown app, left to its record")
            return
        }
        guard let alert = alert(
            id: nextBannerID,
            bundleIdentifier: bundleIdentifier,
            title: banner.title,
            subtitle: banner.subtitle,
            body: banner.body,
            imageURL: nil
        ) else { return }
        nextBannerID -= 1
        let now = Date()
        shownFromBanners.removeAll { now.timeIntervalSince($0.date) > Self.recordWait }
        shownFromBanners.append((alert, now))
        alerts.post(.notification(alert))
        Log.app.debug("notification shown from its banner")
    }

    /// The registered app showing `name` on its banners. Only a single match counts, and
    /// never a website (they are not mirrored); anything else waits for its record.
    private func bundleIdentifier(ofAppNamed name: String) -> String? {
        let matches = appIdentifiers().filter { !Self.isFromWebsite($0) && AppName.of($0) == name }
        return matches.count == 1 ? matches[0] : nil
    }

    /// Whether `alert` was already shown from its banner; forgets it if so.
    private func takeShownFromBanner(_ alert: NotificationAlert) -> Bool {
        guard let index = shownFromBanners.firstIndex(where: { $0.alert.isSame(as: alert) }) else { return false }
        shownFromBanners.remove(at: index)
        return true
    }

    // MARK: Alerts

    /// The banner for one notification under the rules, or `nil` when it is not shown.
    private func alert(
        id: Int64,
        bundleIdentifier: String,
        title: String?,
        subtitle: String?,
        body: String?,
        imageURL: URL?
    ) -> NotificationAlert? {
        let decision = NotificationRules.decide(
            bundleIdentifier: bundleIdentifier,
            ownBundleIdentifier: Bundle.main.bundleIdentifier,
            mode: Preferences.notificationMode(for: bundleIdentifier),
            screenShared: ScreenSharing.isActive,
            focusSilencing: isFocusSilencing(),
            bypassesFocus: Preferences.bypassesFocus(bundleIdentifier)
        )
        let appName = AppName.of(bundleIdentifier)
        switch decision {
        case .drop:
            return nil
        case .appOnly:
            // No title or body: the banner shows the app's name only, and no photo.
            return NotificationAlert(
                id: id,
                bundleIdentifier: bundleIdentifier,
                text: NotificationText.make(title: nil, subtitle: nil, body: nil, appName: appName),
                imageURL: nil
            )
        case .full:
            return NotificationAlert(
                id: id,
                bundleIdentifier: bundleIdentifier,
                text: NotificationText.make(title: title, subtitle: subtitle, body: body, appName: appName),
                imageURL: imageURL
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
