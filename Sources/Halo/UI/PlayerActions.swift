import Foundation

/// What the player UI can ask for, decoupled from who performs it.
@MainActor
struct PlayerActions {
    var togglePlayPause: () -> Void
    var nextTrack: () -> Void
    var previousTrack: () -> Void
    var seek: (TimeInterval) -> Void
    /// A bar is being dragged: keep the island open and interactive.
    var setInteracting: (Bool) -> Void
}

/// What the HUD can ask for.
@MainActor
struct HUDActions {
    var setLevel: (Double) -> Void
    var setInteracting: (Bool) -> Void
}
