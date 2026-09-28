import SwiftUI

/// Previous / play-pause / next, plus the lyrics toggle when the track has synced lyrics.
/// The only Liquid Glass in the island: the body stays black, the controls float on it as
/// glass. With Reduce Transparency they become solid.
struct TransportControls: View {
    let isPlaying: Bool
    let tint: Color
    let hasLyrics: Bool
    let showsLyrics: Bool
    let actions: PlayerActions

    var body: some View {
        HStack(spacing: 0) {
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

            Spacer(minLength: 8)

            if hasLyrics {
                ControlButton(
                    symbol: showsLyrics ? "quote.bubble.fill" : "quote.bubble",
                    label: showsLyrics ? "Nascondi testo" : "Mostra testo",
                    diameter: 28,
                    glyphSize: 11,
                    tint: showsLyrics ? tint : nil
                ) {
                    actions.toggleLyrics()
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: hasLyrics)
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
