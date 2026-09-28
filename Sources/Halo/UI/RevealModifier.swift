import SwiftUI

/// Content appearance for the expanded player: after the shape has opened, elements come
/// in one after another from a slight blur and scale; they leave quickly and together.
struct RevealModifier: ViewModifier {
    let isVisible: Bool
    let order: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .blur(radius: isVisible || reduceMotion ? 0 : 6)
            .scaleEffect(isVisible || reduceMotion ? 1 : 0.94, anchor: .top)
            .allowsHitTesting(isVisible)
            .animation(Motion.reveal(isVisible: isVisible, order: order, reduceMotion: reduceMotion), value: isVisible)
    }
}

extension View {
    func reveal(_ isVisible: Bool, order: Int) -> some View {
        modifier(RevealModifier(isVisible: isVisible, order: order))
    }

    /// Positions a view at `frame`, given in the parent's coordinate space.
    func place(in frame: CGRect) -> some View {
        self
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
    }
}
