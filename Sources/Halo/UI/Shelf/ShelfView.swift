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
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(isDropTargeted ? 0.55 : 0.12),
                    style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
                )
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(isDropTargeted ? 0.08 : 0.02))
                }

            if store.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolEffect(.bounce, value: isDropTargeted)
                    Text(isDropTargeted ? "Rilascia per aggiungere" : "Trascina qui i file")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.6))
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
        .animation(.spring(duration: 0.3, bounce: 0.2), value: isDropTargeted)
        .animation(.spring(duration: 0.4, bounce: 0.15), value: store.items)
    }

    private var clearButton: some View {
        Button(action: actions.clear) {
            VStack(spacing: 6) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                Text("Svuota")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.6))
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
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
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
