import AppKit

/// Chooses the screen that hosts the island and reports display configuration changes
/// (resolution, arrangement, lid closed/opened, monitors plugged in).
@MainActor
final class ScreenTracker {
    private let onChange: () -> Void
    private var observer: (any NSObjectProtocol)?

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onChange()
            }
        }
    }

    /// The built-in display with a notch if there is one, otherwise the primary display
    /// (the one carrying the menu bar).
    static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.screens.first
    }
}
