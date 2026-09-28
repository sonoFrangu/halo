import SwiftUI

/// Everything drawn inside the island body, laid out on the canvas at fixed frames from
/// `IslandLayout`. Artwork and equalizer persist across states and only change frame;
/// expanded-only elements are revealed in sequence.
struct IslandContentView: View {
    let island: IslandViewModel
    let player: NowPlayingModel
    let actions: PlayerActions
    let layout: IslandLayout

    var body: some View {
        let state = island.state
        let hasMedia = island.hasMedia
        let isExpanded = state == .expanded
        let showsActivity = state != .idle && hasMedia
        let showsPlayer = isExpanded && hasMedia
        let tint = player.palette.primary.color

        ZStack(alignment: .topLeading) {
            ExpandedBackdrop(palette: player.palette, layout: layout, isVisible: showsPlayer)

            ArtworkView(
                image: player.artworkImage,
                palette: player.palette,
                cornerRadius: isExpanded ? 14 : 6,
                isProminent: isExpanded
            )
            .place(in: layout.artworkFrame(for: state))
            .opacity(showsActivity ? 1 : 0)

            EqualizerView(isPlaying: player.isPlaying && showsActivity, tint: tint)
                .place(in: layout.equalizerFrame(for: state))
                .opacity(showsActivity ? 1 : 0)

            SourceIconView(icon: player.sourceIcon)
                .place(in: layout.sourceIconFrame)
                .reveal(showsPlayer, order: 0)

            TrackInfoView(title: player.title, artist: player.artist)
                .place(in: layout.trackInfoFrame)
                .reveal(showsPlayer, order: 1)

            TransportControls(isPlaying: player.isPlaying, tint: tint, actions: actions)
                .place(in: layout.controlsFrame)
                .reveal(showsPlayer, order: 2)

            ScrubberView(
                timeline: player.timeline,
                isActive: showsPlayer,
                tint: tint,
                isHovering: island.isScrubberHovered,
                onHoverChanged: { hovering in island.setScrubberHovered(hovering) },
                onScrubbingChanged: actions.setScrubbing,
                onSeek: actions.seek
            )
            .place(in: layout.scrubberFrame)
            .reveal(showsPlayer, order: 3)

            EmptyStateView(availability: player.availability)
                .place(in: layout.emptyStateFrame)
                .reveal(isExpanded && !hasMedia, order: 0)
        }
        .frame(width: layout.canvasSize.width, height: layout.canvasSize.height, alignment: .topLeading)
    }
}
