import Foundation

/// What the player UI can ask for, decoupled from who performs it.
@MainActor
struct PlayerActions {
    var togglePlayPause: () -> Void
    var nextTrack: () -> Void
    var previousTrack: () -> Void
    var seek: (TimeInterval) -> Void
    var toggleLyrics: () -> Void
    /// Brings the playing app to the front (click on the artwork).
    var openSource: () -> Void
    /// A bar is being dragged: keep the island open and interactive.
    var setInteracting: (Bool) -> Void
}

extension PlayerActions {
    /// Controls for the cards outside the island (desktop, lock screen): no lyrics toggle
    /// and no open shape to hold while dragging.
    static func card(for nowPlaying: NowPlayingController) -> PlayerActions {
        PlayerActions(
            togglePlayPause: { [weak nowPlaying] in nowPlaying?.togglePlayPause() },
            nextTrack: { [weak nowPlaying] in nowPlaying?.nextTrack() },
            previousTrack: { [weak nowPlaying] in nowPlaying?.previousTrack() },
            seek: { [weak nowPlaying] position in nowPlaying?.seek(to: position) },
            toggleLyrics: {},
            openSource: { [weak nowPlaying] in nowPlaying?.openSourceApp() },
            setInteracting: { _ in }
        )
    }
}

/// What the HUD can ask for.
@MainActor
struct HUDActions {
    var setLevel: (Double) -> Void
    var setInteracting: (Bool) -> Void
}

/// What alerts can ask for.
@MainActor
struct AlertActions {
    var activate: (IslandAlert) -> Void
}

/// Everything the island UI can ask for.
@MainActor
struct IslandActions {
    var player: PlayerActions
    var hud: HUDActions
    var alerts: AlertActions
    var shelf: ShelfActions
    var calendar: CalendarActions
    var selectTab: (ExpandedTab) -> Void
}

/// The observable models the island UI reads.
@MainActor
struct IslandModels {
    let player: NowPlayingModel
    let hud: HUDModel
    let lyrics: LyricsModel
    let weather: WeatherModel
    let shelf: ShelfStore
    let thumbnails: ShelfThumbnails
    let calendar: CalendarModel
}
