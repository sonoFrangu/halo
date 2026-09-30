import SwiftUI

/// The lock screen card's lyrics under the player: a hairline, then three lines of
/// `LyricsPanel` with the sung line in the middle.
struct LyricsStrip: View {
    let player: NowPlayingModel
    let lyrics: LyricsModel
    let isVisible: Bool
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Rectangle()
                .fill(Fill.primary)
                .frame(height: 0.5)
            LyricsPanel(
                lines: lyrics.lines,
                timeline: player.timeline,
                lead: lyrics.lead,
                palette: player.palette,
                isVisible: isVisible,
                onSeek: onSeek
            )
            .frame(height: 3 * LyricsPanel.lineHeight)
        }
    }
}
