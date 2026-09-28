import SwiftUI

/// Now Playing card shared by the desktop widget and the lock screen: artwork with the
/// source app badge, title, glass controls, progress and the synced lyrics when the track
/// has them.
struct PlayerCardView: View {
    struct Metrics: Equatable {
        var width: CGFloat
        var artworkSide: CGFloat
        var lyricsHeight: CGFloat
        var cornerRadius: CGFloat
        var padding: CGFloat

        static let desktop = Metrics(width: 340, artworkSide: 64, lyricsHeight: 72, cornerRadius: 30, padding: 20)
        static let lockScreen = Metrics(width: 440, artworkSide: 88, lyricsHeight: 96, cornerRadius: 38, padding: 26)
    }

    let player: NowPlayingModel
    let lyrics: LyricsModel
    let card: CardState
    let actions: PlayerActions
    let metrics: Metrics

    var body: some View {
        let tint = player.palette.primary.color
        let showsLyrics = lyrics.status == .synced && !lyrics.lines.isEmpty

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ArtworkView(
                    image: player.artworkImage,
                    palette: player.palette,
                    cornerRadius: metrics.artworkSide * 0.2,
                    isProminent: true
                )
                .frame(width: metrics.artworkSide, height: metrics.artworkSide)
                .overlay(alignment: .bottomTrailing) {
                    SourceIconView(icon: player.sourceIcon)
                        .frame(width: 22, height: 22)
                        .offset(x: 6, y: 6)
                }

                TrackInfoView(title: player.title, artist: player.artist)
                    .frame(height: 40)
            }

            TransportControls(
                isPlaying: player.isPlaying,
                tint: tint,
                hasLyrics: false,
                showsLyrics: false,
                actions: actions
            )
            .frame(height: 36)

            ScrubberView(
                timeline: player.timeline,
                isActive: card.isVisible,
                tint: tint,
                isHovering: card.isScrubberHovered,
                onHoverChanged: { hovering in card.setScrubberHovered(hovering) },
                onScrubbingChanged: actions.setInteracting,
                onSeek: actions.seek,
                minimumInterval: 1
            )
            .frame(height: 20)

            if showsLyrics {
                LyricsPanel(
                    lines: lyrics.lines,
                    timeline: player.timeline,
                    palette: player.palette,
                    isVisible: card.isVisible,
                    onSeek: actions.seek
                )
                .frame(height: metrics.lyricsHeight)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
        }
        .padding(metrics.padding)
        .frame(width: metrics.width)
        .background {
            CardBackdrop(image: player.artworkImage, palette: player.palette, cornerRadius: metrics.cornerRadius)
        }
        .animation(.spring(duration: 0.45, bounce: 0.15), value: showsLyrics)
    }
}
