import SwiftUI

/// Content appearance for the expanded player: after the shape has opened, elements come
/// in one after another from a slight blur and scale; they leave quickly and together.
///
/// `blurs: false` skips the blur for content that is expensive to filter every frame, such
/// as Liquid Glass controls (which sample what is behind them).
struct RevealModifier: ViewModifier {
    let isVisible: Bool
    let order: Int
    let blurs: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.reducesEffects) private var reducesEffects

    func body(content: Content) -> some View {
        let calm = reduceMotion || reducesEffects
        return content
            .opacity(isVisible ? 1 : 0)
            .blur(radius: isVisible || calm || !blurs ? 0 : 6)
            .scaleEffect(isVisible || calm ? 1 : 0.94, anchor: .top)
            .allowsHitTesting(isVisible)
            .animation(Motion.reveal(isVisible: isVisible, order: order, reduceMotion: calm), value: isVisible)
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
