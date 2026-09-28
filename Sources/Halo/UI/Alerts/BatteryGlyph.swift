import SwiftUI

/// A hand-drawn battery: continuous-corner body, terminal nub, a fill that springs to the
/// level, and a bolt while charging. Green while charging, red when low, white otherwise.
struct BatteryGlyph: View {
    let level: Double
    let isCharging: Bool
    let isLow: Bool

    var body: some View {
        GeometryReader { proxy in
            let bodyWidth = max(10, proxy.size.width - 3)
            let bodyHeight = bodyWidth * 0.5
            let inset: CGFloat = 2
            let fillWidth = max(2, (bodyWidth - 2 * inset) * CGFloat(min(max(level, 0), 1)))

            HStack(spacing: 1) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: bodyHeight * 0.32, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.45), lineWidth: 1.2)
                    RoundedRectangle(cornerRadius: (bodyHeight - 2 * inset) * 0.3, style: .continuous)
                        .fill(fill)
                        .frame(width: fillWidth, height: bodyHeight - 2 * inset)
                        .padding(.leading, inset)
                        .shadow(color: glow.opacity(0.6), radius: 4)
                    if isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: bodyHeight * 0.72, weight: .heavy))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.55), radius: 1)
                            .frame(maxWidth: .infinity)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: bodyWidth, height: bodyHeight)

                Capsule()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: 1.8, height: bodyHeight * 0.38)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .animation(.spring(duration: 0.6, bounce: 0.2), value: level)
        .animation(.spring(duration: 0.4, bounce: 0.3), value: isCharging)
        .accessibilityHidden(true)
    }

    private var fill: LinearGradient {
        if isCharging {
            return LinearGradient(colors: [Color(red: 0.2, green: 0.78, blue: 0.35), Color(red: 0.45, green: 0.92, blue: 0.5)], startPoint: .leading, endPoint: .trailing)
        }
        if isLow {
            return LinearGradient(colors: [Color(red: 1, green: 0.27, blue: 0.23), Color(red: 1, green: 0.45, blue: 0.35)], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [Color.white.opacity(0.85), .white], startPoint: .leading, endPoint: .trailing)
    }

    private var glow: Color {
        isCharging ? Color(red: 0.3, green: 0.9, blue: 0.45) : (isLow ? Color(red: 1, green: 0.3, blue: 0.25) : .clear)
    }
}
