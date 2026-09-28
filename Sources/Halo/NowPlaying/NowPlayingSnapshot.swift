import Foundation

/// Encoded artwork bytes. Identity is the `id`, assigned once per distinct image, so
/// comparing snapshots never compares hundreds of kilobytes of image data.
struct ArtworkPayload: Sendable, Equatable {
    let id: UUID
    let data: Data

    static func == (lhs: ArtworkPayload, rhs: ArtworkPayload) -> Bool {
        lhs.id == rhs.id
    }
}

/// Immutable view of what is playing right now, as reported by the adapter.
struct NowPlayingSnapshot: Sendable, Equatable {
    var bundleIdentifier: String?
    var parentBundleIdentifier: String?
    var title: String
    var artist: String?
    var album: String?
    var isPlaying: Bool
    /// `nil` for content without a known duration (e.g. live streams).
    var timeline: PlaybackTimeline?
    var artwork: ArtworkPayload?

    /// The app to show as the source: browsers report a helper process as the player and
    /// the browser itself as the parent application.
    var sourceBundleIdentifier: String? {
        parentBundleIdentifier ?? bundleIdentifier
    }

    func settingPlaying(_ playing: Bool, at date: Date) -> NowPlayingSnapshot {
        var copy = self
        copy.isPlaying = playing
        copy.timeline = timeline?.settingPlaying(playing, at: date)
        return copy
    }

    func seeking(to position: TimeInterval, at date: Date) -> NowPlayingSnapshot {
        var copy = self
        copy.timeline = timeline?.seeking(to: position, at: date)
        return copy
    }
}
