import Foundation

/// A position asked for with the progress bar or a lyrics line, shown until the player
/// reports it back.
///
/// Spotify reports a seek at once, already advancing, but then spends about a second (more
/// on a slow connection) loading the audio there, and only after that republishes the
/// position it really restarted from. Measured on five seeks: the audio restarted about
/// 1.1 s later, from the sought position. Taking the first report made lyrics run a second
/// ahead of the voice and then jump back. For players that load like this the sought
/// position is held still until the restart report arrives; a seek into audio already
/// loaded gets no such report, so after `loadAllowance` the first report is taken instead.
struct PendingSeek {
    var title: String
    /// Where the user asked to go.
    let position: TimeInterval
    /// The sought position. For players that load after a seek it is anchored at
    /// `requestedAt + loadAllowance`, so it holds still until then.
    var timeline: PlaybackTimeline
    var requestedAt: Date
    /// When the seek stops winning over stream positions that disagree with it.
    var until: Date
    var waitsForLoad: Bool

    /// How long a seek wins over stream positions that disagree with it.
    static let hold: TimeInterval = 3
    /// Positions closer than this count as the same.
    static let tolerance: TimeInterval = 1.5
    /// A report anchored this long after the seek is the player's restart, not its
    /// immediate echo of the seek.
    static let restartReportDelay: TimeInterval = 0.5
    /// Longest wait for a restart report before trusting the first one.
    static let loadAllowance: TimeInterval = 1.5
    /// Players measured to report a seek before loading its audio.
    static let loadingPlayers: Set<String> = ["com.spotify.client"]

    init(title: String, from shown: PlaybackTimeline, to position: TimeInterval, player: String?, at now: Date) {
        self.title = title
        self.position = min(max(position, 0), shown.duration)
        requestedAt = now
        until = now.addingTimeInterval(Self.hold)
        waitsForLoad = player.map(Self.loadingPlayers.contains) ?? false
        timeline = shown.seeking(to: position, at: waitsForLoad ? now.addingTimeInterval(Self.loadAllowance) : now)
    }

    /// Whether `reported`, the player's latest timeline, confirms the seek at `now`.
    func isConfirmed(by reported: PlaybackTimeline, at now: Date) -> Bool {
        guard waitsForLoad else {
            return abs(reported.elapsed(at: now) - timeline.elapsed(at: now)) < Self.tolerance
        }
        // Restarted after loading: a fresh report anchored at the sought position.
        if reported.timestamp >= requestedAt.addingTimeInterval(Self.restartReportDelay),
           abs(reported.elapsed - position) < Self.tolerance {
            return true
        }
        // No restart report in time: the audio was already loaded and played on from the
        // sought position, so the first report stands.
        guard now >= requestedAt.addingTimeInterval(Self.loadAllowance) else { return false }
        let unloaded = position + now.timeIntervalSince(requestedAt) * reported.rate
        return abs(reported.elapsed(at: now) - unloaded) < Self.tolerance
    }

    /// The position to show while the seek is pending: still until the load allowance
    /// ends, then advancing only while the player plays.
    func held(at now: Date, isPlaying: Bool) -> PlaybackTimeline {
        PlaybackTimeline(
            duration: timeline.duration,
            elapsed: timeline.elapsed(at: now),
            timestamp: max(now, timeline.timestamp),
            rate: isPlaying ? max(timeline.rate, 1) : 0
        )
    }
}
