import SwiftUI

/// Tab switcher in the expanded island's left wing: small pills, the selected one white.
struct ExpandedTabsView: View {
    let selected: ExpandedTab
    let showsShelf: Bool
    let onSelect: (ExpandedTab) -> Void

    var body: some View {
        HStack(spacing: 6) {
            tab(.player, symbol: "music.note", label: "Musica")
            if showsShelf {
                tab(.shelf, symbol: "tray.full.fill", label: "Scaffale")
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: selected)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: showsShelf)
    }

    private func tab(_ tab: ExpandedTab, symbol: String, label: String) -> some View {
        let isSelected = selected == tab
        return Button {
            onSelect(tab)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.6))
                .frame(width: 28, height: 20)
                .background {
                    Capsule().fill(isSelected ? Color.white : Color.white.opacity(0.08))
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
