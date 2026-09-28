import AppKit
import CoreGraphics

/// "Presentation mode": while the frontmost app is full screen (Keynote, a video, a call),
/// alerts that would cover it wait out (see `AlertCenter.isQuiet`).
///
/// Checked only when the active app or Space changes: the window list is read once (its
/// bounds and owners need no permission) to see whether the frontmost app has a window as
/// large as a display.
@MainActor
final class PresentationDetector {
    private let alerts: AlertCenter
    private var observers: [NSObjectProtocol] = []
    private var checkTask: Task<Void, Never>?
    private(set) var isEnabled = Preferences.presentationModeEnabled

    /// Lets the full-screen transition finish before looking at the windows.
    static let settleDelay: Duration = .milliseconds(600)

    init(alerts: AlertCenter) {
        self.alerts = alerts
    }

    func start() {
        guard isEnabled, observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        let changed: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleCheck()
            }
        }
        observers = [
            center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main, using: changed),
            center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main, using: changed),
        ]
        scheduleCheck()
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
        checkTask?.cancel()
        alerts.isQuiet = false
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.presentationModeEnabled = enabled
        if enabled { start() } else { stop() }
    }

    private func scheduleCheck() {
        checkTask?.cancel()
        checkTask = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled, let self else { return }
            self.alerts.isQuiet = Self.frontmostAppIsFullScreen()
        }
    }

    static func frontmostAppIsFullScreen() -> Bool {
        guard
            let app = NSWorkspace.shared.frontmostApplication,
            app.bundleIdentifier != "com.apple.finder",
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return false }

        let displays = NSScreen.screens.map(\.frame.size)
        return windows.contains { window in
            guard
                (window[kCGWindowOwnerPID as String] as? Int32) == app.processIdentifier,
                (window[kCGWindowLayer as String] as? Int) == 0,
                let boundsInfo = window[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsInfo as CFDictionary)
            else { return false }
            return displays.contains { $0.width == bounds.width && $0.height == bounds.height }
        }
    }
}
