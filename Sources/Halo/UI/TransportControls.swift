import SwiftUI

/// Previous / play-pause / next. The only Liquid Glass in the island: the body stays
/// black, the controls float on it as glass. With Reduce Transparency they become solid.
struct TransportControls: View {
    let isPlaying: Bool
    let tint: Color
    let actions: PlayerActions

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                ControlButton(symbol: "backward.fill", label: "Brano precedente", diameter: 30, glyphSize: 12) {
                    actions.previousTrack()
                }
                ControlButton(
                    symbol: isPlaying ? "pause.fill" : "play.fill",
                    label: isPlaying ? "Pausa" : "Riproduci",
                    diameter: 36,
                    glyphSize: 15,
                    tint: tint
                ) {
                    actions.togglePlayPause()
                }
                ControlButton(symbol: "forward.fill", label: "Brano successivo", diameter: 30, glyphSize: 12) {
                    actions.nextTrack()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct ControlButton: View {
    let symbol: String
    let label: String
    let diameter: CGFloat
    let glyphSize: CGFloat
    var tint: Color?
    let action: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: glyphSize, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .background {
            if reduceTransparency {
                Circle().fill(Color(white: tint == nil ? 0.14 : 0.2))
            }
        }
        .glassEffect(glass, in: Circle())
        .accessibilityLabel(label)
    }

    private var glass: Glass {
        if reduceTransparency {
            return .identity
        }
        if let tint {
            return Glass.regular.tint(tint.opacity(0.35)).interactive(true)
        }
        return Glass.regular.interactive(true)
    }
}
