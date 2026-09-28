import Observation

/// View state of a floating card (desktop widget, lock screen) kept outside the views,
/// because `@State` cannot be used in Command Line Tools builds on the macOS 27 SDK.
@MainActor
@Observable
final class CardState {
    /// The window is on screen: timelines tick only then.
    private(set) var isVisible = false
    private(set) var isScrubberHovered = false

    func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        if !visible {
            isScrubberHovered = false
        }
    }

    func setScrubberHovered(_ hovered: Bool) {
        guard hovered != isScrubberHovered else { return }
        isScrubberHovered = hovered
    }
}
