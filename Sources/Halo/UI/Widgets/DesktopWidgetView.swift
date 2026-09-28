import SwiftUI

/// The desktop widget: the Now Playing card while something plays, otherwise the clock.
/// Drag it anywhere by its background; the controller remembers where.
struct DesktopWidgetView: View {
    let player: NowPlayingModel
    let lyrics: LyricsModel
    let weather: WeatherModel
    let card: CardState
    let actions: PlayerActions

    var body: some View {
        let metrics = PlayerCardView.Metrics.desktop

        ZStack(alignment: .topLeading) {
            if player.hasMedia {
                PlayerCardView(player: player, lyrics: lyrics, card: card, actions: actions, metrics: metrics)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            } else {
                ClockCardView(weather: weather.report, width: metrics.width)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
        }
        .gesture(WindowDragGesture())
        .shadow(color: .black.opacity(0.3), radius: 22, x: 0, y: 12)
        .padding(DesktopWidgetView.shadowMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.spring(duration: 0.5, bounce: 0.15), value: player.hasMedia)
    }

    /// Transparent room around the card for its shadow.
    static let shadowMargin: CGFloat = 40
}
