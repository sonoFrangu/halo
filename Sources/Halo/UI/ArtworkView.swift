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
                    // Takes the proposed size, so a non-square (16:9) cover is cropped by
                    // the clip below instead of widening the view past its frame.
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
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
            shape.strokeBorder(Fill.secondary, lineWidth: 0.5)
        }
        // The colored shadow follows its own delayed animation: it only appears once the
        // artwork has reached its expanded frame, so it is not re-rendered while it moves.
        .animation(isProminent ? .easeOut(duration: 0.3).delay(0.25) : .easeOut(duration: 0.1)) { content in
            content.shadow(
                color: palette.primary.color.opacity(isProminent ? 0.45 : 0),
                radius: isProminent ? 14 : 0,
                x: 0,
                y: isProminent ? 6 : 0
            )
        }
        .accessibilityHidden(true)
    }
}
