import Foundation

/// Playback position expressed as an anchor instead of a ticking value: the elapsed time
/// at `timestamp`, advancing at `rate`. Views evaluate it only when they draw, so nothing
/// polls the adapter or runs a timer to keep the position current.
struct PlaybackTimeline: Sendable, Equatable {
    var duration: TimeInterval
    var elapsed: TimeInterval
    var timestamp: Date
    /// Effective rate: 0 while paused.
    var rate: Double

    var isAdvancing: Bool { rate > 0 }

    func elapsed(at date: Date) -> TimeInterval {
        let advanced = elapsed + max(0, date.timeIntervalSince(timestamp)) * rate
        return min(max(advanced, 0), duration)
    }

    func progress(at date: Date) -> Double {
        guard duration > 0 else { return 0 }
        return elapsed(at: date) / duration
    }

    func remaining(at date: Date) -> TimeInterval {
        max(0, duration - elapsed(at: date))
    }

    /// Re-anchors the timeline at `date`, e.g. for an optimistic play/pause toggle.
    func settingPlaying(_ isPlaying: Bool, at date: Date) -> PlaybackTimeline {
        PlaybackTimeline(
            duration: duration,
            elapsed: elapsed(at: date),
            timestamp: date,
            rate: isPlaying ? max(rate, 1) : 0
        )
    }

    /// Re-anchors the timeline at a new position, e.g. for an optimistic seek.
    func seeking(to position: TimeInterval, at date: Date) -> PlaybackTimeline {
        PlaybackTimeline(
            duration: duration,
            elapsed: min(max(position, 0), duration),
            timestamp: date,
            rate: rate
        )
    }
}
