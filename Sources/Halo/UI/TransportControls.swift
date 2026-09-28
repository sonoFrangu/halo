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

/// A round glass control. The glass is drawn by the button style, inside the button, and
/// is not `interactive`: interactive glass wrapped around a `Button` runs its own press
/// tracking, which could swallow a click (the play button sometimes needed several). The
/// whole disc is the hit area and shrinks while pressed.
struct ControlButton: View {
    let symbol: String
    let label: String
    let diameter: CGFloat
    let glyphSize: CGFloat
    var tint: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: glyphSize, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(GlassDiscButtonStyle(diameter: diameter, tint: tint))
        .accessibilityLabel(label)
    }
}

struct GlassDiscButtonStyle: ButtonStyle {
    let diameter: CGFloat
    var tint: Color?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .frame(width: diameter, height: diameter)
            .background {
                if reduceTransparency {
                    Circle().fill(Color(white: tint == nil ? 0.14 : 0.2))
                }
            }
            .glassEffect(glass, in: Circle())
            .overlay {
                Circle().fill(.white.opacity(pressed ? 0.12 : 0))
            }
            .contentShape(Circle())
            .scaleEffect(pressed && !reduceMotion ? 0.88 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.1) : Motion.press, value: pressed)
    }

    private var glass: Glass {
        if reduceTransparency {
            return .identity
        }
        if let tint {
            return Glass.regular.tint(tint.opacity(0.35))
        }
        return .regular
    }
}
