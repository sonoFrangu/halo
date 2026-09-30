import SwiftUI

/// Background of the floating widgets, macOS 26 widget style: plain Liquid Glass, lightly
/// darkened so white text stays readable on any wallpaper, and a hairline border; nothing
/// tinted by the artwork. Solid with Reduce Transparency.
struct WidgetBackdrop: View {
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Group {
            if reduceTransparency {
                shape.fill(Color(white: 0.12))
            } else {
                Color.clear.glassEffect(.regular.tint(Color.black.opacity(0.22)), in: shape)
            }
        }
        .overlay {
            shape.strokeBorder(Fill.primary, lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}
