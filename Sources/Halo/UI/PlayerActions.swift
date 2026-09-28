import Foundation

/// What the player UI can ask for, decoupled from who performs it.
@MainActor
struct PlayerActions {
    var togglePlayPause: () -> Void
    var nextTrack: () -> Void
    var previousTrack: () -> Void
    var seek: (TimeInterval) -> Void
    var setScrubbing: (Bool) -> Void
}
