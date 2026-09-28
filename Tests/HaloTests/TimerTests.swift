import Foundation
import Testing
@testable import Halo

struct FocusTimerTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func runningTimersCountDownFromTheirEnd() {
        let timer = FocusTimer.start(.countdown, duration: 300, at: now)
        #expect(timer.isRunning)
        #expect(timer.remaining(at: now.addingTimeInterval(60)) == 240)
        #expect(abs(timer.progress(at: now.addingTimeInterval(150)) - 0.5) < 1e-9)
        #expect(timer.remaining(at: now.addingTimeInterval(900)) == 0)
    }

    @Test func pausingFreezesTheRemainingTime() {
        let paused = FocusTimer.start(.countdown, duration: 300, at: now).paused(at: now.addingTimeInterval(100))
        #expect(!paused.isRunning)
        #expect(paused.remaining(at: now.addingTimeInterval(1000)) == 200)

        let resumed = paused.resumed(at: now.addingTimeInterval(1000))
        #expect(resumed.remaining(at: now.addingTimeInterval(1050)) == 150)
    }

    @Test func addingTimeExtendsTheEndAndStaysUnderAnHour() {
        let timer = FocusTimer.start(.countdown, duration: 60, at: now).adding(60, at: now)
        #expect(timer.remaining(at: now) == 120)
        #expect(timer.duration == 120)

        let long = FocusTimer.start(.countdown, duration: 59 * 60, at: now).adding(10 * 60, at: now)
        #expect(long.remaining(at: now) == FocusTimer.maximumDuration)
    }
}

struct PomodoroTests {
    @Test func aCycleIsFourFocusRoundsThenALongBreak() {
        var mode = TimerMode.focus(round: 1)
        var sequence: [TimerMode] = [mode]
        while let next = Pomodoro.next(after: mode) {
            sequence.append(next)
            mode = next
        }
        #expect(sequence == [
            .focus(round: 1), .shortBreak(afterRound: 1),
            .focus(round: 2), .shortBreak(afterRound: 2),
            .focus(round: 3), .shortBreak(afterRound: 3),
            .focus(round: 4), .longBreak,
        ])
    }

    @Test func countdownsDoNotContinue() {
        #expect(Pomodoro.next(after: .countdown) == nil)
        #expect(Pomodoro.duration(of: .countdown) == nil)
    }

    @Test func alertsDescribeWhatComesNext() {
        #expect(TimerAlert(finished: .countdown, next: nil).title == "Tempo scaduto")
        let toBreak = TimerAlert(finished: .focus(round: 2), next: .shortBreak(afterRound: 2))
        #expect(toBreak.title == "Pausa")
        #expect(toBreak.isBreak)
        #expect(TimerAlert(finished: .focus(round: 4), next: .longBreak).title == "Pausa lunga")
        #expect(TimerAlert(finished: .shortBreak(afterRound: 1), next: .focus(round: 2)).message.hasPrefix("Focus 2 di 4"))
    }
}
