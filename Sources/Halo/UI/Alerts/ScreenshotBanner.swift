import AppKit
import SwiftUI

/// What the screenshot banner can ask for.
@MainActor
struct ScreenshotActions {
    var open: (URL) -> Void
    var copy: (URL) -> Void
    var keep: (URL) -> Void
    var trash: (URL) -> Void
}

/// A new screenshot: its thumbnail (drag it anywhere), and copy / keep on the shelf / trash.
/// Clicking the thumbnail opens it.
struct ScreenshotBanner: View {
    let alert: ScreenshotAlert
    let thumbnails: ShelfThumbnails
    let actions: ScreenshotActions

    var body: some View {
        let url = alert.url

        HStack(spacing: 12) {
            Image(nsImage: thumbnails.image(for: ShelfItem(url: url)))
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: 78, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: Corner.tile, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Corner.tile, style: .continuous)
                        .strokeBorder(Fill.primary, lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 2)
                .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
                .onTapGesture { actions.open(url) }
                .accessibilityLabel("Apri lo screenshot")

            VStack(alignment: .leading, spacing: 1) {
                Text("Screenshot")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Trascinalo dove vuoi")
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.secondary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                iconButton("doc.on.doc", label: "Copia") { actions.copy(url) }
                iconButton("tray.and.arrow.down", label: "Tieni sullo scaffale") { actions.keep(url) }
                iconButton("trash", label: "Sposta nel Cestino") { actions.trash(url) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Ink.primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Fill.primary))
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(label)
        .help(label)
    }
}
