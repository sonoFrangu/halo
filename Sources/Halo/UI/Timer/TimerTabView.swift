import SwiftUI

/// What the timer UI can ask for.
@MainActor
struct TimerActions {
    var start: (Int) -> Void
    var startPomodoro: () -> Void
    var togglePause: () -> Void
    var addMinute: () -> Void
    var stop: () -> Void
}

/// The timer tab: presets and Pomodoro when idle; a ring, the countdown and controls while
/// a timer exists.
struct TimerTabView: View {
    let timers: TimerController
    let actions: TimerActions

    var body: some View {
        if let timer = timers.timer {
            ActiveTimerView(timer: timer, actions: actions)
                .transition(.opacity)
        } else {
            TimerPresetsView(actions: actions)
                .transition(.opacity)
        }
    }
}

struct ActiveTimerView: View {
    let timer: FocusTimer
    let actions: TimerActions

    var body: some View {
        let tint = TimerPalette.tint(for: timer.mode)

        HStack(spacing: 20) {
            ring
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

    @ViewBuilder
    private var ring: some View {
        if timer.isRunning {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                TimerRing(progress: timer.progress(at: context.date), mode: timer.mode, lineWidth: 7)
            }
        } else {
            TimerRing(progress: timer.progress(at: Date()), mode: timer.mode, lineWidth: 7)
                .opacity(0.6)
        }
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
            Button(action: actions.startPomodoro) {
                Label("Pomodoro  25 + 5", systemImage: "leaf.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 28)
                    .background {
                        Capsule().fill(
                            LinearGradient(
                                colors: TimerPalette.colors(for: .focus(round: 1)),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }
                    .contentShape(Capsule())
            }
            .buttonStyle(PressableButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
