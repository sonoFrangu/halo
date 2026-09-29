import AppKit

/// The glass widget on the desktop: above the wallpaper and the desktop icons, below every
/// window, on all Spaces. Off by default; its position is remembered.
@MainActor
final class DesktopWidgetController {
    private let player: NowPlayingModel
    private let weather: WeatherModel
    private let actions: PlayerActions
    private let card = CardState()
    private var panel: CardPanel?
    private(set) var isEnabled = Preferences.desktopWidgetEnabled

    /// Widget plus the transparent margin for its shadow.
    static let size = CGSize(
        width: PlayerWidgetView.Metrics.desktop.width + 2 * DesktopWidgetView.shadowMargin,
        height: PlayerWidgetView.Metrics.desktop.height + 2 * DesktopWidgetView.shadowMargin
    )
    private static let autosaveName = "HaloDesktopWidget"

    init(player: NowPlayingModel, weather: WeatherModel, actions: PlayerActions) {
        self.player = player
        self.weather = weather
        self.actions = actions
    }

    func start() {
        guard isEnabled else { return }
        show()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.desktopWidgetEnabled = enabled
        if enabled { show() } else { hide() }
    }

    private func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }) {
            // Its display was disconnected.
            panel.setFrameOrigin(Self.defaultOrigin(for: panel.frame.size))
        }
        panel.orderFrontRegardless()
        card.setVisible(true)
    }

    private func hide() {
        panel?.orderOut(nil)
        card.setVisible(false)
    }

    private func makePanel() -> CardPanel {
        let level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        let panel = CardPanel.make(
            size: Self.size,
            level: level,
            behavior: [.canJoinAllSpaces, .stationary, .ignoresCycle]
        )
        panel.contentView = CardHostingView(
            rootView: DesktopWidgetView(player: player, weather: weather, card: card, actions: actions)
        )
        if panel.setFrameUsingName(Self.autosaveName) {
            // Keep the saved position (top edge) but this version's size.
            let frame = panel.frame
            panel.setFrame(
                NSRect(x: frame.minX, y: frame.maxY - Self.size.height, width: Self.size.width, height: Self.size.height),
                display: false
            )
        } else {
            panel.setFrameOrigin(Self.defaultOrigin(for: Self.size))
        }
        panel.setFrameAutosaveName(Self.autosaveName)
        return panel
    }

    /// Top-right corner of the main display, under the menu bar.
    private static func defaultOrigin(for size: CGSize) -> CGPoint {
        let visible = (NSScreen.screens.first ?? NSScreen.main)?.visibleFrame ?? .zero
        return CGPoint(x: visible.maxX - size.width, y: visible.maxY - size.height)
    }
}
