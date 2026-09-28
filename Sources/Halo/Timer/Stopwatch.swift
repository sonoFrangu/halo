import Foundation

/// A stopwatch, as a value: while running, the moment it would have started had it never
/// paused (views count up from it on their own, nothing ticks); while paused, the time
/// measured so far.
struct Stopwatch: Sendable, Equatable {
    /// Set while running.
    var startDate: Date?
    /// Set while paused.
    var pausedElapsed: TimeInterval?

    static func started(at now: Date) -> Stopwatch {
        Stopwatch(startDate: now, pausedElapsed: nil)
    }

    var isRunning: Bool {
        startDate != nil
    }

    func elapsed(at now: Date) -> TimeInterval {
        if let startDate {
            return max(0, now.timeIntervalSince(startDate))
        }
        return max(0, pausedElapsed ?? 0)
    }

    func paused(at now: Date) -> Stopwatch {
        guard isRunning else { return self }
        return Stopwatch(startDate: nil, pausedElapsed: elapsed(at: now))
    }

    func resumed(at now: Date) -> Stopwatch {
        guard let pausedElapsed else { return self }
        return Stopwatch(startDate: now.addingTimeInterval(-pausedElapsed), pausedElapsed: nil)
    }
}
