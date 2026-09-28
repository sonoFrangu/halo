import Foundation

/// What a timer is counting.
enum TimerMode: Sendable, Equatable {
    /// A plain countdown.
    case countdown
    /// A Pomodoro focus round (1...rounds).
    case focus(round: Int)
    /// The short break after a focus round.
    case shortBreak(afterRound: Int)
    /// The long break that closes a Pomodoro cycle.
    case longBreak

    var isBreak: Bool {
        switch self {
        case .shortBreak, .longBreak: true
        case .countdown, .focus: false
        }
    }
}

/// The Pomodoro cycle: four 25-minute focus rounds separated by 5-minute breaks, then a
/// 15-minute break.
enum Pomodoro {
    static let rounds = 4
    static let focus: TimeInterval = 25 * 60
    static let shortBreak: TimeInterval = 5 * 60
    static let longBreak: TimeInterval = 15 * 60

    static func duration(of mode: TimerMode) -> TimeInterval? {
        switch mode {
        case .countdown: nil
        case .focus: focus
        case .shortBreak: shortBreak
        case .longBreak: longBreak
        }
    }

    /// What starts when `mode` ends; `nil` when the cycle (or a countdown) is over.
    static func next(after mode: TimerMode) -> TimerMode? {
        switch mode {
        case .countdown, .longBreak:
            nil
        case .focus(let round):
            round < rounds ? .shortBreak(afterRound: round) : .longBreak
        case .shortBreak(let round):
            .focus(round: round + 1)
        }
    }
}

/// A running or paused timer, as a value: the end date while running (the display derives
/// the remaining time from it, nothing ticks), the remaining time while paused.
struct FocusTimer: Sendable, Equatable {
    var mode: TimerMode
    /// Total length, including added minutes.
    var duration: TimeInterval
    /// Set while running.
    var endDate: Date?
    /// Set while paused.
    var pausedRemaining: TimeInterval?

    /// Timers stay under an hour so the countdown fits the island's wing.
    static let maximumDuration: TimeInterval = 59 * 60 + 59

    static func start(_ mode: TimerMode, duration: TimeInterval, at now: Date) -> FocusTimer {
        let duration = min(max(duration, 1), maximumDuration)
        return FocusTimer(mode: mode, duration: duration, endDate: now.addingTimeInterval(duration), pausedRemaining: nil)
    }

    var isRunning: Bool {
        endDate != nil
    }

    func remaining(at now: Date) -> TimeInterval {
        if let endDate {
            return max(0, endDate.timeIntervalSince(now))
        }
        return max(0, pausedRemaining ?? 0)
    }

    /// Elapsed share of the timer, 0...1.
    func progress(at now: Date) -> Double {
        guard duration > 0 else { return 1 }
        return min(max(1 - remaining(at: now) / duration, 0), 1)
    }

    func paused(at now: Date) -> FocusTimer {
        guard isRunning else { return self }
        return FocusTimer(mode: mode, duration: duration, endDate: nil, pausedRemaining: remaining(at: now))
    }

    func resumed(at now: Date) -> FocusTimer {
        guard let pausedRemaining else { return self }
        return FocusTimer(mode: mode, duration: duration, endDate: now.addingTimeInterval(pausedRemaining), pausedRemaining: nil)
    }

    /// Adds time (e.g. "+1 min"), within `maximumDuration` of remaining time.
    func adding(_ seconds: TimeInterval, at now: Date) -> FocusTimer {
        let remaining = remaining(at: now)
        let added = min(seconds, Self.maximumDuration - remaining)
        guard added > 0 else { return self }
        var copy = self
        copy.duration += added
        if let endDate {
            copy.endDate = endDate.addingTimeInterval(added)
        } else {
            copy.pausedRemaining = remaining + added
        }
        return copy
    }
}
