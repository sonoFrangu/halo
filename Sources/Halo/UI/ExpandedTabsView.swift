import SwiftUI

/// Tab switcher in the expanded island's left wing: small pills, the selected one white.
struct ExpandedTabsView: View {
    let tabs: [ExpandedTab]
    let selected: ExpandedTab
    /// Room in the wing (`IslandLayout.tabsFrame`).
    let width: CGFloat
    let onSelect: (ExpandedTab) -> Void

    static let pillSize = CGSize(width: 24, height: 20)
    static let spacing: CGFloat = 4

    /// Full-size pills, narrower when they would not all fit the wing (five tabs do not fit
    /// a wide notch).
    static func pillWidth(count: Int, available: CGFloat) -> CGFloat {
        guard count > 1 else { return pillSize.width }
        let fitting = (available - spacing * CGFloat(count - 1)) / CGFloat(count)
        return min(pillSize.width, fitting.rounded(.down))
    }

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
        let pillWidth = Self.pillWidth(count: tabs.count, available: width)
        return Button {
            onSelect(tab)
        } label: {
            Image(systemName: tab.symbol)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(isSelected ? Color.black : Ink.secondary)
                .frame(width: pillWidth, height: Self.pillSize.height)
                .background {
                    Capsule().fill(isSelected ? Color.white : Fill.secondary)
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
        case .clipboard: "list.clipboard.fill"
        case .calendar: "calendar"
        case .timer: "timer"
        }
    }

    var title: String {
        switch self {
        case .player: "Musica"
        case .shelf: "Scaffale"
        case .clipboard: "Appunti"
        case .calendar: "Calendario"
        case .timer: "Timer"
        }
    }
}
