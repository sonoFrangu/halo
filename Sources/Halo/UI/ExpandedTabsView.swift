import SwiftUI

/// Tab switcher in the expanded island's left wing: small pills, the selected one white.
struct ExpandedTabsView: View {
    let tabs: [ExpandedTab]
    let selected: ExpandedTab
    let onSelect: (ExpandedTab) -> Void

    /// Sized so four tabs fit the narrowest wing.
    static let pillSize = CGSize(width: 24, height: 20)
    static let spacing: CGFloat = 4

    var body: some View {
        HStack(spacing: Self.spacing) {
            ForEach(tabs, id: \.self) { tab in
                pill(tab)
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: selected)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: tabs)
    }

    private func pill(_ tab: ExpandedTab) -> some View {
        let isSelected = selected == tab
        return Button {
            onSelect(tab)
        } label: {
            Image(systemName: tab.symbol)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.6))
                .frame(width: Self.pillSize.width, height: Self.pillSize.height)
                .background {
                    Capsule().fill(isSelected ? Color.white : Color.white.opacity(0.08))
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension ExpandedTab {
    var symbol: String {
        switch self {
        case .player: "music.note"
        case .shelf: "tray.full.fill"
        case .calendar: "calendar"
        }
    }

    var title: String {
        switch self {
        case .player: "Musica"
        case .shelf: "Scaffale"
        case .calendar: "Calendario"
        }
    }
}
