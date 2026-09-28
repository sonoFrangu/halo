import SwiftUI

/// The Apple Intelligence edge glow along the island's outline while Siri is on screen.
/// It turns slowly; with Reduce Motion or reduced effects it holds still.
struct SiriGlowView: View {
    let shape: NotchShape

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.reducesEffects) private var reducesEffects

    static let colors: [Color] = [
        Color(red: 0.98, green: 0.38, blue: 0.69),
        Color(red: 0.62, green: 0.4, blue: 1),
        Color(red: 0.29, green: 0.6, blue: 1),
        Color(red: 0.36, green: 0.9, blue: 0.9),
        Color(red: 1, green: 0.62, blue: 0.3),
        Color(red: 0.98, green: 0.38, blue: 0.69),
    ]
    /// Seconds per turn.
    static let period: Double = 4

    var body: some View {
        let still = reduceMotion || reducesEffects
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: still)) { context in
            let turn = still ? 0 : (context.date.timeIntervalSinceReferenceDate / Self.period).truncatingRemainder(dividingBy: 1)
            let gradient = AngularGradient(colors: Self.colors, center: .center, angle: .degrees(turn * 360))
            ZStack {
                shape.stroke(gradient, lineWidth: 8).blur(radius: 7)
                shape.stroke(gradient, lineWidth: 1.5)
            }
            .clipShape(shape)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Left wing while Siri is on screen: a waveform in Siri's colors.
struct SiriGlyph: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "waveform")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(LinearGradient(colors: SiriGlowView.colors, startPoint: .leading, endPoint: .trailing))
            .symbolEffect(.variableColor.iterative, isActive: isActive && !reduceMotion)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Siri")
    }
}
