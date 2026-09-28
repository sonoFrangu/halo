import SwiftUI

/// What the timer UI can ask for.
@MainActor
struct TimerActions {
    var start: (Int) -> Void
    var startPomodoro: () -> Void
    var togglePause: () -> Void
    var addMinute: () -> Void
    var stop: () -> Void
    var toggleStopwatch: () -> Void
    var resetStopwatch: () -> Void
}

/// The timer tab: presets, Pomodoro and stopwatch when idle; the running timer or
/// stopwatch with its controls; both as two rows when both run.
struct TimerTabView: View {
    let timers: TimerController
    let actions: TimerActions
    /// On screen: dials and rings tick only then.
    let isVisible: Bool

    var body: some View {
        switch (timers.timer, timers.stopwatch) {
        case let (timer?, stopwatch?):
            VStack(spacing: 10) {
                ActivityRow(
                    title: timer.mode.label,
                    tint: TimerPalette.tint(for: timer.mode),
                    isRunning: timer.isRunning,
                    onToggle: actions.togglePause,
                    onStop: actions.stop
                ) {
                    TimerRingView(timer: timer, isVisible: isVisible, lineWidth: 4)
                } value: {
                    TimerCountdownText(timer: timer)
                }
                ActivityRow(
                    title: "Cronometro",
                    tint: StopwatchPalette.tint,
                    isRunning: stopwatch.isRunning,
                    onToggle: actions.toggleStopwatch,
                    onStop: actions.resetStopwatch
                ) {
                    StopwatchDial(stopwatch: stopwatch, isVisible: isVisible, lineWidth: 3)
                } value: {
                    StopwatchText(stopwatch: stopwatch)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        case let (timer?, nil):
            ActiveTimerView(timer: timer, actions: actions, isVisible: isVisible)
                .transition(.opacity)
        case let (nil, stopwatch?):
            ActiveStopwatchView(stopwatch: stopwatch, actions: actions, isVisible: isVisible)
                .transition(.opacity)
        case (nil, nil):
            TimerPresetsView(actions: actions)
                .transition(.opacity)
        }
    }
}

/// The timer's ring, redrawn once a second only while running and on screen.
struct TimerRingView: View {
    let timer: FocusTimer
    let isVisible: Bool
    let lineWidth: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1, paused: !isVisible || !timer.isRunning)) { context in
            TimerRing(progress: timer.progress(at: context.date), mode: timer.mode, lineWidth: lineWidth)
        }
        .opacity(timer.isRunning ? 1 : 0.6)
    }
}

struct ActiveTimerView: View {
    let timer: FocusTimer
    let actions: TimerActions
    let isVisible: Bool

    var body: some View {
        let tint = TimerPalette.tint(for: timer.mode)

        HStack(spacing: 20) {
            TimerRingView(timer: timer, isVisible: isVisible, lineWidth: 7)
                .frame(width: 82, height: 82)
                .overlay {
                    Image(systemName: timer.mode.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(tint)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(timer.isRunning ? timer.mode.label : "\(timer.mode.label) · in pausa")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(tint)
                    .textCase(.uppercase)
                TimerCountdownText(timer: timer)
                    .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                HStack(spacing: 10) {
                    ControlButton(
                        symbol: timer.isRunning ? "pause.fill" : "play.fill",
                        label: timer.isRunning ? "Pausa" : "Riprendi",
                        diameter: 30,
                        glyphSize: 12,
                        tint: tint,
                        action: actions.togglePause
                    )
                    ControlButton(symbol: "plus", label: "Un minuto in più", diameter: 30, glyphSize: 12, action: actions.addMinute)
                    ControlButton(symbol: "xmark", label: "Ferma", diameter: 30, glyphSize: 12, action: actions.stop)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TimerPresetsView: View {
    let actions: TimerActions

    var body: some View {
        VStack(spacing: 12) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(TimerController.presets, id: \.self) { minutes in
                        TimerPresetButton(minutes: minutes) { actions.start(minutes) }
                    }
                }
            }
            HStack(spacing: 10) {
                CapsuleActionButton(
                    title: "Pomodoro  25 + 5",
                    symbol: "leaf.fill",
                    colors: TimerPalette.colors(for: .focus(round: 1)),
                    action: actions.startPomodoro
                )
                CapsuleActionButton(
                    title: "Cronometro",
                    symbol: "stopwatch.fill",
                    colors: StopwatchPalette.colors,
                    action: actions.toggleStopwatch
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A colorful capsule that starts something (Pomodoro, stopwatch).
struct CapsuleActionButton: View {
    let title: String
    let symbol: String
    let colors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 28)
                .background {
                    Capsule().fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// A round glass preset: the number of minutes over "min".
struct TimerPresetButton: View {
    let minutes: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: -1) {
                Text("\(minutes)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text("min")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)
        }
        .buttonStyle(GlassDiscButtonStyle(diameter: 42))
        .accessibilityLabel("Timer di \(minutes) minuti")
    }
}

extension TimerMode {
    var label: String {
        switch self {
        case .countdown: "Timer"
        case .focus(let round): "Focus \(round)/\(Pomodoro.rounds)"
        case .shortBreak: "Pausa"
        case .longBreak: "Pausa lunga"
        }
    }

    var symbol: String {
        switch self {
        case .countdown: "timer"
        case .focus: "brain.head.profile"
        case .shortBreak, .longBreak: "cup.and.saucer.fill"
        }
    }
}
