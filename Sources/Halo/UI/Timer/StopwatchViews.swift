import SwiftUI

enum StopwatchPalette {
    static let colors = [Color(red: 0.39, green: 0.82, blue: 1), Color(red: 0.35, green: 0.34, blue: 0.84)]
    static var tint: Color { colors[0] }
}

/// Time measured: counted up by the system while running (no redraw of the island each
/// second), fixed while paused.
struct StopwatchText: View {
    let stopwatch: Stopwatch

    var body: some View {
        if let start = stopwatch.startDate {
            Text(timerInterval: start...Date.distantFuture, countsDown: false)
        } else {
            Text(TimeFormatting.string(stopwatch.elapsed(at: Date())))
        }
    }
}

/// A watch face whose hand sweeps once a minute. It ticks once a second, and only while
/// running and on screen.
struct StopwatchDial: View {
    let stopwatch: Stopwatch
    let isVisible: Bool
    var lineWidth: CGFloat = 7

    var body: some View {
        TimelineView(.animation(minimumInterval: 1, paused: !isVisible || !stopwatch.isRunning)) { context in
            dial(seconds: stopwatch.elapsed(at: context.date))
        }
        .accessibilityHidden(true)
    }

    private func dial(seconds: TimeInterval) -> some View {
        let colors = StopwatchPalette.colors
        let angle = Angle.degrees(seconds.truncatingRemainder(dividingBy: 60) / 60 * 360)
        return ZStack {
            Circle()
                .stroke(
                    AngularGradient(colors: colors + [colors[0]], center: .center),
                    lineWidth: lineWidth
                )
                .opacity(stopwatch.isRunning ? 1 : 0.55)
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - lineWidth * 1.6
                for tick in 0..<12 {
                    let theta = Double(tick) / 12 * 2 * .pi
                    let outer = CGPoint(x: center.x + sin(theta) * radius, y: center.y - cos(theta) * radius)
                    let inner = CGPoint(x: center.x + sin(theta) * (radius - 5), y: center.y - cos(theta) * (radius - 5))
                    var path = Path()
                    path.move(to: inner)
                    path.addLine(to: outer)
                    context.stroke(path, with: .color(.white.opacity(0.35)), lineWidth: 1.5)
                }
            }
            Capsule()
                .fill(StopwatchPalette.tint)
                .frame(width: 2.5, height: 26)
                .offset(y: -13)
                .rotationEffect(angle)
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
        }
        .padding(lineWidth / 2)
    }
}

/// The stopwatch filling the timer tab.
struct ActiveStopwatchView: View {
    let stopwatch: Stopwatch
    let actions: TimerActions
    let isVisible: Bool

    var body: some View {
        HStack(spacing: 20) {
            StopwatchDial(stopwatch: stopwatch, isVisible: isVisible)
                .frame(width: 82, height: 82)

            VStack(alignment: .leading, spacing: 2) {
                Text(stopwatch.isRunning ? "Cronometro" : "Cronometro · in pausa")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(StopwatchPalette.tint)
                    .textCase(.uppercase)
                StopwatchText(stopwatch: stopwatch)
                    .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                HStack(spacing: 10) {
                    ControlButton(
                        symbol: stopwatch.isRunning ? "pause.fill" : "play.fill",
                        label: stopwatch.isRunning ? "Pausa" : "Riprendi",
                        diameter: 30,
                        glyphSize: 12,
                        tint: StopwatchPalette.tint,
                        action: actions.toggleStopwatch
                    )
                    ControlButton(symbol: "xmark", label: "Azzera", diameter: 30, glyphSize: 12, action: actions.resetStopwatch)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One line of the timer tab when a timer and the stopwatch both run.
struct ActivityRow<Leading: View, Value: View>: View {
    let title: String
    let tint: Color
    let isRunning: Bool
    let onToggle: () -> Void
    let onStop: () -> Void
    @ViewBuilder let leading: Leading
    @ViewBuilder let value: Value

    var body: some View {
        HStack(spacing: 12) {
            leading
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(tint)
                    .textCase(.uppercase)
                value
                    .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 8)
            ControlButton(
                symbol: isRunning ? "pause.fill" : "play.fill",
                label: isRunning ? "Pausa" : "Riprendi",
                diameter: 28,
                glyphSize: 11,
                tint: tint,
                action: onToggle
            )
            ControlButton(symbol: "xmark", label: "Ferma", diameter: 28, glyphSize: 11, action: onStop)
        }
        .padding(.horizontal, 12)
    }
}
