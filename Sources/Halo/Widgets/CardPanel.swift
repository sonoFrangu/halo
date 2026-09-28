import AppKit
import SwiftUI

/// Borderless, transparent, non-activating panel for the floating cards (desktop widget,
/// lock screen). It never becomes key, so using its controls never takes focus from the
/// frontmost app; fully transparent areas let clicks through to what is below.
final class CardPanel: NSPanel {
    static func make(size: CGSize, level: NSWindow.Level, behavior: NSWindow.CollectionBehavior) -> CardPanel {
        let panel = CardPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = level
        panel.collectionBehavior = behavior
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.isExcludedFromWindowsMenu = true
        panel.animationBehavior = .none
        return panel
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Hosting view that takes the first click, so controls respond without activating Halo.
final class CardHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
