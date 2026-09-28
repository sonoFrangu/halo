import AppKit
import SwiftUI

/// Album artwork with continuous corners. Prominent (expanded) artwork casts a shadow in
/// its own dominant color; without artwork a gradient placeholder uses the palette.
struct ArtworkView: View {
    let image: NSImage?
    let palette: ArtworkPalette
    let cornerRadius: CGFloat
    let isProminent: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .id(ObjectIdentifier(image))
                    .transition(.opacity)
            } else {
                LinearGradient(
                    colors: [palette.primary.color, palette.secondary.color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "music.note")
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.85))
                    .scaleEffect(0.42)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: image.map { ObjectIdentifier($0) })
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(
            color: palette.primary.color.opacity(isProminent ? 0.45 : 0),
            radius: isProminent ? 14 : 0,
            x: 0,
            y: isProminent ? 6 : 0
        )
        .accessibilityHidden(true)
    }
}
