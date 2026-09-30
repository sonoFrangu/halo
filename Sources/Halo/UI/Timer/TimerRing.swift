import SwiftUI

/// Colors of the timer: warm while working or counting down, green on breaks.
enum TimerPalette {
    static func colors(for mode: TimerMode) -> [Color] {
        mode.isBreak
            ? [Color(red: 0.19, green: 0.82, blue: 0.35), Color(red: 0.39, green: 0.82, blue: 1)]
            : [Color(red: 1, green: 0.62, blue: 0.04), Color(red: 1, green: 0.27, blue: 0.23)]
    }

    static func tint(for mode: TimerMode) -> Color {
        colors(for: mode)[0]
    }
}

/// Progress ring that empties as time runs out, with a gradient along the arc and a round
/// cap. Its owner redraws it once a second; it is never animated between seconds.
struct TimerRing: View {
    /// Elapsed share, 0...1.
    let progress: Double
    let mode: TimerMode
    let lineWidth: CGFloat

    var body: some View {
        let colors = TimerPalette.colors(for: mode)
        ZStack {
            Circle()
                .stroke(Fill.primary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(max(0.001, 1 - progress)))
                .stroke(
                    AngularGradient(colors: colors + [colors[0]], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: colors[0].opacity(0.5), radius: lineWidth)
        }
        .padding(lineWidth / 2)
        .accessibilityHidden(true)
    }
}

/// Remaining time: counted down by the system while running (no per-second redraw of the
/// island), fixed while paused.
struct TimerCountdownText: View {
    let timer: FocusTimer

    var body: some View {
        if let end = timer.endDate {
            let now = Date()
            Text(timerInterval: min(now, end)...end, countsDown: true)
        } else {
            Text(TimeFormatting.string(timer.remaining(at: Date())))
        }
    }
}
