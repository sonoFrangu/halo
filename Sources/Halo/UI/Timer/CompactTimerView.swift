import SwiftUI

/// What the compact island shows besides music, most important first: the timer, the
/// stopwatch, then a download or AirDrop.
enum LiveActivity: Equatable {
    case timer(FocusTimer)
    case stopwatch(Stopwatch)
    case transfer(Transfer)

    @MainActor
    static func current(timers: TimerController, transfers: TransferMonitor) -> LiveActivity? {
        if let timer = timers.timer { return .timer(timer) }
        if let stopwatch = timers.stopwatch { return .stopwatch(stopwatch) }
        if let transfer = transfers.current { return .transfer(transfer) }
        return nil
    }
}

/// Left wing, in the artwork's place when nothing plays.
struct LiveActivityLeading: View {
    let activity: LiveActivity
    let isVisible: Bool

    var body: some View {
        switch activity {
        case .timer(let timer):
            TimerRingView(timer: timer, isVisible: isVisible, lineWidth: 2.5)
        case .stopwatch(let stopwatch):
            Image(systemName: "stopwatch.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(StopwatchPalette.tint.opacity(stopwatch.isRunning ? 1 : 0.55))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .transfer(let transfer):
            TransferRing(transfer: transfer, lineWidth: 2.5)
        }
    }
}

/// Right wing: the countdown, the stopwatch or the percentage. With music playing (the
/// artwork holds the left wing) a transfer also shows its ring here.
struct LiveActivityTrailing: View {
    let activity: LiveActivity
    let hasMedia: Bool

    var body: some View {
        Group {
            switch activity {
            case .timer(let timer):
                TimerCountdownText(timer: timer)
                    .foregroundStyle(TimerPalette.tint(for: timer.mode).opacity(timer.isRunning ? 1 : 0.55))
            case .stopwatch(let stopwatch):
                StopwatchText(stopwatch: stopwatch)
                    .foregroundStyle(StopwatchPalette.tint.opacity(stopwatch.isRunning ? 1 : 0.55))
            case .transfer(let transfer):
                HStack(spacing: 5) {
                    if hasMedia {
                        TransferRing(transfer: transfer, lineWidth: 2)
                            .frame(width: 15, height: 15)
                    }
                    Text(transfer.fraction, format: .percent.precision(.fractionLength(0)))
                        .foregroundStyle(TransferPalette.tint(for: transfer.kind))
                }
            }
        }
        .font(.system(size: 11.5, weight: .semibold, design: .rounded).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum TransferPalette {
    static func tint(for kind: Transfer.Kind) -> Color {
        switch kind {
        case .download: Color(red: 0.2, green: 0.78, blue: 0.35)
        case .airDrop: Color(red: 0.04, green: 0.52, blue: 1)
        }
    }

    static func symbol(for kind: Transfer.Kind) -> String {
        switch kind {
        case .download: "arrow.down"
        case .airDrop: "antenna.radiowaves.left.and.right"
        }
    }
}

/// Progress of a download or AirDrop around its arrow.
struct TransferRing: View {
    let transfer: Transfer
    let lineWidth: CGFloat

    var body: some View {
        let tint = TransferPalette.tint(for: transfer.kind)
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(max(0.02, min(transfer.fraction, 1))))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: transfer.fraction)
            Image(systemName: TransferPalette.symbol(for: transfer.kind))
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(tint)
        }
        .padding(lineWidth / 2)
        .accessibilityHidden(true)
    }
}
