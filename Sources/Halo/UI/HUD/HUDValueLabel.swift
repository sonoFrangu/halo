import SwiftUI

/// Percentage after the HUD bar, rolling digits as it changes.
struct HUDValueLabel: View {
    let level: Double
    let isMuted: Bool

    var body: some View {
        let percent = Int((min(max(level, 0), 1) * 100).rounded())
        Text(isMuted ? "–" : "\(percent)")
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .foregroundStyle(.white.opacity(0.75))
            .contentTransition(.numericText(value: Double(percent)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .animation(.spring(duration: 0.3, bounce: 0.1), value: percent)
            .accessibilityHidden(true)
    }
}
