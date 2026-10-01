import SwiftUI

/// Content appearance for the expanded player: after the shape has opened, elements come
/// in one after another from a slight blur and scale; they leave quickly and together.
///
/// Every element grows out of the notch's center, wherever it sits (a wing, a banner, a
/// row inside a banner), so the whole island opens from the middle outward like the shape.
///
/// `blurs: false` skips the blur for content that is expensive to filter every frame, such
/// as Liquid Glass controls (which sample what is behind them).
struct RevealModifier: ViewModifier {
    let isVisible: Bool
    let order: Int
    let blurs: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.reducesEffects) private var reducesEffects

    /// Scale of hidden content: how far toward the notch's center it starts.
    static let hiddenScale = 0.88

    func body(content: Content) -> some View {
        let calm = reduceMotion || reducesEffects
        let scale = isVisible || calm ? 1 : Self.hiddenScale
        return content
            .opacity(isVisible ? 1 : 0)
            .blur(radius: isVisible || calm || !blurs ? 0 : 6)
            .visualEffect { content, proxy in
                content.scaleEffect(scale, anchor: IslandCanvas.notchCenter(in: proxy))
            }
            .allowsHitTesting(isVisible)
            .animation(Motion.reveal(isVisible: isVisible, order: order, reduceMotion: calm), value: isVisible)
    }
}

/// The island's canvas, named so content can find the notch from anywhere inside it.
enum IslandCanvas {
    static let space = "island"

    /// The top of the notch's center, as an anchor in the view's own bounds; the view's top
    /// center outside the island.
    nonisolated static func notchCenter(in proxy: GeometryProxy) -> UnitPoint {
        // The canvas's bounds come in the view's own coordinates.
        let size = proxy.size
        guard let canvas = proxy.bounds(of: .named(space)), size.width > 0, size.height > 0 else { return .top }
        return UnitPoint(x: canvas.midX / size.width, y: canvas.minY / size.height)
    }
}

extension View {
    func reveal(_ isVisible: Bool, order: Int, blurs: Bool = true) -> some View {
        modifier(RevealModifier(isVisible: isVisible, order: order, blurs: blurs))
    }

    /// Positions a view at `frame`, given in the parent's coordinate space.
    func place(in frame: CGRect) -> some View {
        self
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
    }
}
