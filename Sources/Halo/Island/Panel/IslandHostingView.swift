import AppKit
import SwiftUI

/// Hosting view for the island.
///
/// - Accepts the first mouse click, so controls respond without activating Halo.
/// - Reports pointer movement through an `.activeAlways` tracking area: while the panel
///   accepts mouse events the cursor's events are routed to it, and this keeps hover
///   detection working whether or not Halo is the active app.
/// - Offers scroll events to `onScroll` (island gestures); unhandled ones go on as usual.
final class IslandHostingView<Content: View>: NSHostingView<Content> {
    var onPointerActivity: (() -> Void)?
    /// Returns `true` when the event was used by a gesture.
    var onScroll: ((NSEvent) -> Bool)?
    private var pointerTrackingArea: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let pointerTrackingArea {
            removeTrackingArea(pointerTrackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        pointerTrackingArea = area
    }

    override func scrollWheel(with event: NSEvent) {
        if onScroll?(event) == true {
            return
        }
        super.scrollWheel(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        onPointerActivity?()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onPointerActivity?()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onPointerActivity?()
    }
}
