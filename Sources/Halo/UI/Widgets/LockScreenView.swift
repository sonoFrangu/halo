import SwiftUI

/// The lock screen card: the Now Playing card at lock screen size, fading in over the
/// wallpaper.
struct LockScreenView: View {
    let player: NowPlayingModel
    let lyrics: LyricsModel
    let card: CardState
    let actions: PlayerActions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isShown = card.isVisible && player.hasMedia

        PlayerWidgetView(player: player, lyrics: lyrics, card: card, actions: actions, metrics: .lockScreen)
            .shadow(color: .black.opacity(0.35), radius: 30, x: 0, y: 16)
            .opacity(isShown ? 1 : 0)
            .scaleEffect(isShown || reduceMotion ? 1 : 0.94, anchor: .top)
            .animation(reduceMotion ? Motion.content : Motion.appear, value: isShown)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, LockScreenView.shadowMargin)
    }

    static let shadowMargin: CGFloat = 48
}
