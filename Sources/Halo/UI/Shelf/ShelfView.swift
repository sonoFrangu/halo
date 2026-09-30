import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The shelf tab: a row of stashed files with Quick Look thumbnails. Drop files anywhere on
/// it to add them; drag a file out to use it; click to open; right-click for more.
struct ShelfView: View {
    let store: ShelfStore
    let thumbnails: ShelfThumbnails
    let isDropTargeted: Bool
    let actions: ShelfActions

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: IslandLayout.tabCornerRadius, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? Ink.secondary : Fill.primary,
                    style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
                )
                .background {
                    RoundedRectangle(cornerRadius: IslandLayout.tabCornerRadius, style: .continuous)
                        .fill(isDropTargeted ? Fill.secondary : Fill.tertiary)
                }

            if store.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(Glyph.hero)
                        .symbolEffect(.bounce, value: isDropTargeted)
                    Text(isDropTargeted ? "Rilascia per aggiungere" : "Trascina qui i file")
                        .font(Typography.callout.weight(.semibold))
                }
                .foregroundStyle(Ink.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.items) { item in
                            ShelfTile(item: item, image: thumbnails.image(for: item), actions: actions)
                        }
                        clearButton
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .onDrop(of: [.fileURL], delegate: ShelfDropDelegate(actions: actions))
        .animation(Motion.hoverFeedback, value: isDropTargeted)
        .animation(Motion.layout, value: store.items)
    }

    private var clearButton: some View {
        Button(action: actions.clear) {
            VStack(spacing: 6) {
                Image(systemName: "trash")
                    .font(Glyph.button)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Fill.primary))
                Text("Svuota")
                    .font(Typography.caption)
            }
            .foregroundStyle(Ink.secondary)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Svuota lo scaffale")
    }
}

/// One file on the shelf.
struct ShelfTile: View {
    let item: ShelfItem
    let image: NSImage
    let actions: ShelfActions

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
            Text(item.name)
                .font(Typography.caption)
                .foregroundStyle(Ink.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 64)
        }
        .contentShape(Rectangle())
        .onTapGesture { actions.open(item) }
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .contextMenu {
            Button("Apri") { actions.open(item) }
            Button("Mostra nel Finder") { actions.reveal(item) }
            Divider()
            Button("Rimuovi dallo scaffale") { actions.remove(item) }
        }
        .transition(.scale(scale: 0.6).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Accepts file URLs and reports when a drag hovers the shelf.
struct ShelfDropDelegate: DropDelegate {
    let actions: ShelfActions

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }

    func dropEntered(info: DropInfo) {
        actions.setTargeted(true)
    }

    func dropExited(info: DropInfo) {
        actions.setTargeted(false)
    }

    func performDrop(info: DropInfo) -> Bool {
        actions.setTargeted(false)
        let providers = info.itemProviders(for: [.fileURL])
        guard !providers.isEmpty else { return false }
        actions.drop(providers)
        return true
    }
}

/// What the shelf UI can ask for.
@MainActor
struct ShelfActions {
    var drop: ([NSItemProvider]) -> Void
    var setTargeted: (Bool) -> Void
    var open: (ShelfItem) -> Void
    var reveal: (ShelfItem) -> Void
    var remove: (ShelfItem) -> Void
    var clear: () -> Void
}
