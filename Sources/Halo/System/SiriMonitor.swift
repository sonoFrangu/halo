import AppKit
import ApplicationServices

/// Notices Siri on screen so the island can glow while it listens and answers.
///
/// Siri's windows belong to two processes, Siri.app and "Siri AI" (`com.apple.campo`). An
/// Accessibility observer wakes the monitor when either opens a window or changes focus;
/// the window list (owner PIDs need no permission) then says whether one is on screen.
/// While Siri is visible the list is checked twice a second, since a window closing is not
/// reliably notified. Without Accessibility the list is checked once a second.
@MainActor
final class SiriMonitor {
    private(set) var isEnabled = Preferences.siriEnabled
    private var isVisible = false
    private let alerts: AlertCenter
    private var observers: [pid_t: AXObserver] = [:]
    private var launchObserver: NSObjectProtocol?
    private var pollTask: Task<Void, Never>?

    static let bundleIdentifiers: Set<String> = ["com.apple.Siri", "com.apple.campo"]
    private static let holder = "siri"

    init(alerts: AlertCenter) {
        self.alerts = alerts
    }

    func start() {
        guard isEnabled, launchObserver == nil else { return }
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.attach()
            }
        }
        attach()
        check()
    }

    func stop() {
        if let launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(launchObserver)
        }
        launchObserver = nil
        for observer in observers.values {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observers.removeAll()
        pollTask?.cancel()
        pollTask = nil
        setVisible(false)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.siriEnabled = enabled
        if enabled { start() } else { stop() }
    }

    /// Looks again at the window list and schedules the next look when one is needed.
    fileprivate func check() {
        let visible = Self.isOnScreen(pids: Set(observers.keys).union(Self.siriPIDs()))
        setVisible(visible)
        pollTask?.cancel()
        let interval: Duration?
        if visible {
            interval = .milliseconds(500)
        } else if observers.isEmpty {
            // ponytail: polling without Accessibility; event driven once it is granted.
            interval = .seconds(1)
        } else {
            interval = nil
        }
        guard let interval else { return }
        pollTask = Task { [weak self] in
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled else { return }
            self?.check()
        }
    }

    private func attach() {
        guard AXIsProcessTrusted() else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for pid in Self.siriPIDs() where observers[pid] == nil {
            var created: AXObserver?
            guard AXObserverCreate(pid, siriObserverCallback, &created) == .success, let observer = created else { continue }
            let app = AXUIElementCreateApplication(pid)
            for name in [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification, kAXUIElementDestroyedNotification] {
                AXObserverAddNotification(observer, app, name as CFString, refcon)
            }
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
            observers[pid] = observer
        }
    }

    private func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        Diagnostics.shared.record(visible ? "Siri a schermo" : "Siri chiusa")
        if visible {
            alerts.post(.siri)
            alerts.setInteracting(true, by: Self.holder)
        } else {
            alerts.setInteracting(false, by: Self.holder)
            alerts.withdraw(.siri)
        }
    }

    private static func siriPIDs() -> [pid_t] {
        NSWorkspace.shared.runningApplications
            .filter { bundleIdentifiers.contains($0.bundleIdentifier ?? "") }
            .map(\.processIdentifier)
    }

    private static func isOnScreen(pids: Set<pid_t>) -> Bool {
        guard
            !pids.isEmpty,
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else {
            return false
        }
        return windows.contains { window in
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t, pids.contains(pid) else { return false }
            return (window[kCGWindowAlpha as String] as? Double ?? 1) > 0
        }
    }
}

/// What the C callback hands to the main actor. `@unchecked Sendable`: the observers'
/// run loop sources are on the main run loop, so the callback runs on the main thread.
private struct SiriObserverContext: @unchecked Sendable {
    let monitor: UnsafeMutableRawPointer
}

/// C callback of the Accessibility observers (always on the main thread, see above).
private func siriObserverCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let context = SiriObserverContext(monitor: refcon)
    MainActor.assumeIsolated {
        Unmanaged<SiriMonitor>.fromOpaque(context.monitor).takeUnretainedValue().check()
    }
}
