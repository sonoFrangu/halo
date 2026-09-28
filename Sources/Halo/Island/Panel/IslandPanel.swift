import AppKit

/// Borderless, non-activating panel floating above the menu bar on every Space.
///
/// It can never become key or main, so it never takes focus from the frontmost app, and it
/// ignores mouse events unless the island is expanded under the cursor
/// (see `IslandViewModel.onInteractivityChange`).
final class IslandPanel: NSPanel {
    /// `.nonactivatingPanel` must be part of the style mask at creation time.
    static func make() -> IslandPanel {
        let panel = IslandPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.configure()
        return panel
    }

    private func configure() {
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isMovable = false
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Borderless windows may still be pushed below the menu bar; the island lives on it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
