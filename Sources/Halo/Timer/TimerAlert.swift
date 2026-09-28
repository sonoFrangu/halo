import Foundation

/// A timer ended; with Pomodoro, the next phase has already started.
struct TimerAlert: Sendable, Equatable {
    var finished: TimerMode
    var next: TimerMode?

    var title: String {
        switch (finished, next) {
        case (.countdown, _): "Tempo scaduto"
        case (.focus, .longBreak?): "Pausa lunga"
        case (.focus, _): "Pausa"
        case (.shortBreak, _): "Si riparte"
        case (.longBreak, _): "Pomodoro completato"
        }
    }

    var message: String {
        switch (finished, next) {
        case (.countdown, _):
            "Il timer è finito"
        case (.focus, .longBreak?):
            "Ciclo completato · \(Int(Pomodoro.longBreak / 60)) minuti di pausa"
        case (.focus(let round), _):
            "Round \(round) di \(Pomodoro.rounds) completato · \(Int(Pomodoro.shortBreak / 60)) minuti di pausa"
        case (.shortBreak, .focus(let round)?):
            "Focus \(round) di \(Pomodoro.rounds) · \(Int(Pomodoro.focus / 60)) minuti"
        case (.shortBreak, _):
            "Torna al lavoro"
        case (.longBreak, _):
            "Ottimo lavoro!"
        }
    }

    /// Break phases are green, focus and plain timers warm.
    var isBreak: Bool {
        next?.isBreak ?? false
    }
}
