import AppKit
import Observation

enum AdapterAvailability: Equatable {
    case starting
    case running
    case unavailable(String)
}

/// Observable Now Playing state for the UI. Written only by `NowPlayingController`.
@MainActor
@Observable
final class NowPlayingModel {
    var snapshot: NowPlayingSnapshot?
    var artworkImage: NSImage?
    var palette: ArtworkPalette = .neutral
    var sourceIcon: NSImage?
    var availability: AdapterAvailability = .starting

    var hasMedia: Bool { snapshot != nil }
    var isPlaying: Bool { snapshot?.isPlaying ?? false }
    var title: String { snapshot?.title ?? "" }
    var artist: String? { snapshot?.artist }
    var timeline: PlaybackTimeline? { snapshot?.timeline }
}
