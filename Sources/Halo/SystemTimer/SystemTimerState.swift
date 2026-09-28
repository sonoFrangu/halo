import Foundation

/// A Clock timer as the island shows it.
struct SystemTimer: Sendable, Equatable {
    var id: String
    var end: Date
    /// Length when first seen running, kept across pauses so the ring shows real progress.
    var total: TimeInterval

    /// Shown exactly like Halo's own countdown.
    var focusTimer: FocusTimer {
        FocusTimer(mode: .countdown, duration: total, endDate: end, pausedRemaining: nil)
    }
}

/// Folds the log's events into the timer to show.
struct SystemTimerState {
    private(set) var current: SystemTimer?
    /// Lengths of the timers seen so far, by id: a resumed timer keeps its own.
    private var totals: [String: TimeInterval] = [:]

    /// Applies an event; returns `true` when a timer just fired.
    mutating func apply(_ event: SystemTimerEvent, now: Date) -> Bool {
        switch event {
        case .running(let id, let end):
            guard end > now else { return false }
            let total = totals[id] ?? end.timeIntervalSince(now)
            totals[id] = total
            current = SystemTimer(id: id, end: end, total: total)
            return false
        case .cleared:
            current = nil
            return false
        case .fired(let id):
            totals[id] = nil
            current = nil
            return true
        }
    }
}
