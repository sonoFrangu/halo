import AppKit
import SwiftUI

/// The clipboard tab: the last texts and images copied, newest first. Click one to copy it
/// again, drag it out to drop it somewhere, right-click for more.
struct ClipboardTabView: View {
    let history: ClipboardHistory
    let actions: ClipboardActions

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.02))

            if history.items.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Quello che copi compare qui")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.6))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(history.items) { item in
                            ClipboardTile(item: item, isCopied: history.copiedID == item.id, actions: actions)
                        }
                        clearButton
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.15), value: history.items.map(\.id))
        .animation(.easeOut(duration: 0.2), value: history.copiedID)
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
        .accessibilityLabel("Svuota gli appunti")
    }
}

/// One copied text or image.
struct ClipboardTile: View {
    let item: ClipboardItem
    let isCopied: Bool
    let actions: ClipboardActions

    static let size = CGSize(width: 116, height: 78)

    var body: some View {
        VStack(spacing: 6) {
            preview
                .frame(width: Self.size.width, height: Self.size.height)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.08)))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    if isCopied {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.black.opacity(0.55))
                            Label("Copiato", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .transition(.opacity)
                    }
                }
        }
        .contentShape(Rectangle())
        .onTapGesture { actions.copy(item) }
        .onDrag { item.itemProvider }
        .contextMenu {
            Button("Copia") { actions.copy(item) }
            Divider()
            Button("Rimuovi") { actions.remove(item) }
        }
        .transition(.scale(scale: 0.6).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Copia di nuovo")
    }

    @ViewBuilder
    private var preview: some View {
        switch item.content {
        case .text(let text):
            Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)
        case .image:
            if let thumbnail = item.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .accessibilityLabel("Immagine")
            }
        }
    }
}

extension ClipboardItem {
    /// What a drag out of the tab carries.
    var itemProvider: NSItemProvider {
        switch content {
        case .text(let text):
            NSItemProvider(object: text as NSString)
        case .image(let data, let type):
            NSItemProvider(item: data as NSData, typeIdentifier: type)
        }
    }
}

/// What the clipboard tab can ask for.
@MainActor
struct ClipboardActions {
    var copy: (ClipboardItem) -> Void
    var remove: (ClipboardItem) -> Void
    var clear: () -> Void
}
