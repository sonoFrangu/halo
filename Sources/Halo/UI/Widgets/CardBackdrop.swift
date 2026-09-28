import AppKit
import SwiftUI

/// Background of the floating cards: Liquid Glass washed with the artwork, which is blurred
/// into a soft color field (Apple Music style) and darkened toward the bottom so white text
/// stays readable on any wallpaper. With Reduce Transparency the glass becomes solid.
struct CardBackdrop: View {
    let image: NSImage?
    let palette: ArtworkPalette
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            if reduceTransparency {
                Color(white: 0.07)
            }
            LinearGradient(
                colors: [
                    palette.primary.color.opacity(0.5),
                    palette.secondary.color.opacity(0.28),
                    Color.black.opacity(0.25),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.4)
                    .blur(radius: 44)
                    .opacity(0.42)
                    .id(ObjectIdentifier(image))
                    .transition(.opacity)
            }
            LinearGradient(
                colors: [Color.black.opacity(0.02), Color.black.opacity(0.42)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .animation(.easeInOut(duration: 0.6), value: image.map { ObjectIdentifier($0) })
        .clipShape(shape)
        .glassEffect(reduceTransparency ? .identity : .regular, in: shape)
        .overlay {
            shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}
