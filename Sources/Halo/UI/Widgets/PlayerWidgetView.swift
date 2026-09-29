import SwiftUI

/// Now Playing widget in the style of a macOS 26 medium widget: artwork on the left; source
/// app, title, artist and album, progress and controls on the right. The desktop widget
/// shows it alone; the lock screen passes `lyrics` and gets the synced lyrics under it,
/// inside the same glass.
struct PlayerWidgetView: View {
    struct Metrics: Equatable {
        var width: CGFloat
        var artworkSide: CGFloat
        var cornerRadius: CGFloat
        var padding: CGFloat

        static let desktop = Metrics(width: 360, artworkSide: 142, cornerRadius: 22, padding: 14)
        static let lockScreen = Metrics(width: 380, artworkSide: 150, cornerRadius: 26, padding: 16)

        /// Height of the widget without lyrics.
        var height: CGFloat { artworkSide + 2 * padding }
    }

    let player: NowPlayingModel
    let lyrics: LyricsModel?
    let card: CardState
    let actions: PlayerActions
    let metrics: Metrics

    var body: some View {
        let showsLyrics = lyrics.map { $0.status == .synced && !$0.lines.isEmpty } ?? false

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ArtworkView(image: player.artworkImage, palette: player.palette, cornerRadius: 12, isProminent: false)
                    .frame(width: metrics.artworkSide, height: metrics.artworkSide)
                    .onTapGesture { actions.openSource() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Apri l'app in riproduzione")

                details
            }
            .frame(height: metrics.artworkSide)

            if showsLyrics, let lyrics {
                LyricsStrip(player: player, lyrics: lyrics, isVisible: card.isVisible, onSeek: actions.seek)
                    .transition(.opacity)
            }
        }
        .padding(metrics.padding)
        .frame(width: metrics.width)
        .background {
            WidgetBackdrop(cornerRadius: metrics.cornerRadius)
        }
        .animation(.spring(duration: 0.45, bounce: 0.15), value: showsLyrics)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let source = player.snapshot?.sourceBundleIdentifier {
                HStack(spacing: 4) {
                    SourceIconView(icon: player.sourceIcon)
                        .frame(width: 12, height: 12)
                    Text(AppName.of(source))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                .padding(.bottom, 6)
            }
            Text(player.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            ScrubberView(
                timeline: player.timeline,
                isActive: card.isVisible,
                tint: player.palette.primary.color,
                isHovering: card.isScrubberHovered,
                onHoverChanged: { hovering in card.setScrubberHovered(hovering) },
                onScrubbingChanged: actions.setInteracting,
                onSeek: actions.seek,
                minimumInterval: 1
            )
            .frame(height: 20)

            TransportControls(
                isPlaying: player.isPlaying,
                tint: player.palette.primary.color,
                hasLyrics: false,
                showsLyrics: false,
                actions: actions
            )
            .frame(height: 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// "Artist — Album", or whichever of the two exists.
    private var subtitle: String? {
        let parts = [player.artist, player.snapshot?.album].compactMap { part -> String? in
            guard let part, !part.isEmpty else { return nil }
            return part
        }
        return parts.isEmpty ? nil : parts.joined(separator: " — ")
    }
}
