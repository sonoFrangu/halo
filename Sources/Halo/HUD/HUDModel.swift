import Observation

enum HUDKind: Sendable, Equatable {
    case brightness
    case volume
}

/// What the HUD shows. Written only by `HUDController`; whether it is visible is decided by
/// `AlertCenter` (the `.hud` alert).
@MainActor
@Observable
final class HUDModel {
    var kind: HUDKind = .volume
    /// 0...1.
    var level: Double = 0
    var isMuted = false
    var route: SystemVolume.Route = .speakers
}
