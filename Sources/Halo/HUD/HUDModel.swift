import Observation

enum HUDKind: Sendable, Equatable {
    case brightness
    case volume
}

/// What the HUD island shows. Written only by `HUDController`.
@MainActor
@Observable
final class HUDModel {
    var isVisible = false
    var kind: HUDKind = .volume
    /// 0...1.
    var level: Double = 0
    var isMuted = false
    var route: SystemVolume.Route = .speakers
}
