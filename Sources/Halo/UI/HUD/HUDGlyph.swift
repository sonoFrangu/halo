import SwiftUI

/// Left-wing glyph of the HUD. Brightness is a small or full sun, as in macOS; volume shows
/// the output device (AirPods, headphones) or a speaker whose waves fill with the level.
struct HUDGlyph: View {
    let kind: HUDKind
    let level: Double
    let isMuted: Bool
    let route: SystemVolume.Route

    var body: some View {
        Image(systemName: symbol, variableValue: variableValue)
            .font(Glyph.wing)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isMuted ? Ink.secondary : Ink.primary)
            .contentTransition(.symbolEffect(.replace))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(Motion.value, value: level)
            .accessibilityLabel(kind == .brightness ? "Luminosità" : "Volume")
    }

    private var symbol: String {
        switch kind {
        case .brightness:
            return level < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .volume:
            if isMuted { return "speaker.slash.fill" }
            switch route {
            case .airPods: return "airpods"
            case .airPods3: return "airpods.gen3"
            case .airPods4: return "airpods.gen4"
            case .airPodsPro: return "airpodspro"
            case .airPodsMax: return "airpodsmax"
            case .headphones: return "headphones"
            case .speakers: return "speaker.wave.3.fill"
            }
        }
    }

    /// Only the speaker has variable layers (its waves).
    private var variableValue: Double? {
        kind == .volume && route == .speakers && !isMuted ? level : nil
    }
}
