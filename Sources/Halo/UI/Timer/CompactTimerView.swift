import SwiftUI

/// The timer as a live activity in the compact island: the countdown in the right wing.
struct CompactTimerCountdown: View {
    let timer: FocusTimer

    var body: some View {
        TimerCountdownText(timer: timer)
            .font(.system(size: 11.5, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(TimerPalette.tint(for: timer.mode).opacity(timer.isRunning ? 1 : 0.55))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The timer's ring in the left wing when nothing is playing (the artwork's place).
struct CompactTimerRing: View {
    let timer: FocusTimer

    var body: some View {
        if timer.isRunning {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                TimerRing(progress: timer.progress(at: context.date), mode: timer.mode, lineWidth: 2.5)
            }
        } else {
            TimerRing(progress: timer.progress(at: Date()), mode: timer.mode, lineWidth: 2.5)
                .opacity(0.55)
        }
    }
}
