import AppKit
import Observation

/// Announces Focus changes in the island, like iOS, and lets the notification mirror keep
/// quiet while a Focus is on.
///
/// Reads the Do Not Disturb store (`FocusStore`), which needs Full Disk Access, and
/// watches its folder with kqueue: nothing runs between changes. Only Focuses turned on
/// by hand are seen; one started by its schedule leaves no record there.
@MainActor
@Observable
final class FocusMonitor {
    enum Status: Equatable {
        case off
        case needsFullDiskAccess
        case running
    }

    private(set) var status: Status = .off
    private(set) var active: FocusMode?
    private(set) var isEnabled = Preferences.focusEnabled

    @ObservationIgnored private let alerts: AlertCenter
    @ObservationIgnored private var watcher: DatabaseChangeWatcher?
    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    init(alerts: AlertCenter) {
        self.alerts = alerts
    }

    func start() {
        guard isEnabled, status != .running else { return }
        guard (try? FileManager.default.contentsOfDirectory(atPath: FocusStore.directory.path)) != nil else {
            status = .needsFullDiskAccess
            waitForAccess()
            return
        }
        stopWaitingForAccess()
        refresh(announce: false)
        let watcher = DatabaseChangeWatcher(databaseURL: FocusStore.assertionsURL) { [weak self] in
            self?.refresh(announce: true)
        }
        watcher.start()
        self.watcher = watcher
        status = .running
    }

    func stop() {
        watcher?.stop()
        watcher = nil
        stopWaitingForAccess()
        active = nil
        status = .off
        alerts.withdraw(.focus)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.focusEnabled = enabled
        if enabled { start() } else { stop() }
    }

    /// Retries after the user may have granted Full Disk Access.
    func refreshAccess() {
        guard isEnabled, status != .running else { return }
        start()
    }

    private func refresh(announce: Bool) {
        let identifier = (try? Data(contentsOf: FocusStore.assertionsURL))
            .flatMap(FocusStore.activeIdentifier(assertions:))
        let mode = identifier.map { identifier in
            let modes = (try? Data(contentsOf: FocusStore.configurationsURL)).map(FocusStore.modes(configurations:)) ?? [:]
            return modes[identifier] ?? FocusStore.mode(identifier: identifier)
        }
        let previous = active
        active = mode
        guard announce, mode?.identifier != previous?.identifier else { return }
        if let mode {
            alerts.post(.focus(FocusAlert(mode: mode, isOn: true)))
        } else if let previous {
            alerts.post(.focus(FocusAlert(mode: previous, isOn: false)))
        }
    }

    /// No notification announces a Full Disk Access grant: retry on every app switch
    /// (e.g. back from System Settings).
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
