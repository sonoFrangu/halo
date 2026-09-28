import AppKit
import SwiftUI

/// Owns the island panel: hosts the SwiftUI root, sizes the panel around the notch and
/// toggles click-through.
@MainActor
final class IslandPanelController {
    private let panel: IslandPanel
    private let hostingView: IslandHostingView<IslandRootView>

    var onPointerActivity: (() -> Void)? {
        get { hostingView.onPointerActivity }
        set { hostingView.onPointerActivity = newValue }
    }

    var onScroll: ((NSEvent) -> Bool)? {
        get { hostingView.onScroll }
        set { hostingView.onScroll = newValue }
    }

    init(rootView: IslandRootView) {
        panel = IslandPanel.make()
        hostingView = IslandHostingView(rootView: rootView)
        // The panel frame is driven by the notch geometry, never by SwiftUI content, and
        // the root view handles the notch itself instead of being inset by safe areas.
        hostingView.sizingOptions = []
        hostingView.safeAreaRegions = []
        panel.contentView = hostingView
    }

    /// Places the canvas so its horizontal center is the notch center and its top edge is
    /// the top of the screen.
    func show(geometry: NotchGeometry, layout: IslandLayout) {
        let canvas = layout.canvasSize
        let frame = CGRect(
            x: geometry.notchCenterX - canvas.width / 2,
            y: geometry.screenFrame.maxY - canvas.height,
            width: canvas.width,
            height: canvas.height
        )
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
        }
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func setInteractive(_ interactive: Bool) {
        panel.ignoresMouseEvents = !interactive
    }
}
