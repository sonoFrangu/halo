import SwiftUI

/// A timer ended: what finished and, with Pomodoro, what has just started. "Ferma" ends
/// the cycle.
struct TimerBanner: View {
    let alert: TimerAlert
    let onStop: () -> Void

    var body: some View {
        let colors = TimerPalette.colors(for: alert.next ?? alert.finished)

        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: symbol)
                    .font(Glyph.tile)
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)
            .shadow(color: colors[0].opacity(0.5), radius: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(alert.title)
                    .font(Typography.headline)
                    .foregroundStyle(.white)
                Text(alert.message)
                    .font(Typography.subheadline)
                    .foregroundStyle(Ink.secondary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            if alert.next != nil {
                Button(action: onStop) {
                    Text("Ferma")
                        .font(Typography.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 24)
                        .background(Capsule().fill(Fill.primary))
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        if let next = alert.next {
            return next.symbol
        }
        return alert.finished == .longBreak ? "checkmark.seal.fill" : "bell.fill"
    }
}
