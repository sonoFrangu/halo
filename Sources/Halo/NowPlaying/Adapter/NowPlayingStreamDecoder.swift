import Foundation

/// Turns the adapter's `stream --micros` output into snapshots.
///
/// Each line is `{"type":"data","diff":Bool,"payload":{…}}`. A non-diff payload replaces
/// the whole state (an empty one means nothing is playing); a diff payload only carries
/// changed keys, with `null` marking a key that disappeared. Artwork arrives base64
/// encoded and is decoded once per distinct image.
///
/// Not `Sendable`: it lives inside the single task that consumes the adapter's stdout.
struct NowPlayingStreamDecoder {
    enum Output: Equatable {
        /// The line was not a data message (or not valid JSON).
        case ignored
        /// New state; `nil` when no player reports anything.
        case update(NowPlayingSnapshot?)
    }

    private enum Key {
        static let bundleIdentifier = "bundleIdentifier"
        static let parentBundleIdentifier = "parentApplicationBundleIdentifier"
        static let playing = "playing"
        static let title = "title"
        static let artist = "artist"
        static let album = "album"
        static let durationMicros = "durationMicros"
        static let elapsedTimeMicros = "elapsedTimeMicros"
        static let timestampEpochMicros = "timestampEpochMicros"
        static let playbackRate = "playbackRate"
        static let artworkData = "artworkData"    }

    private static let longestDurationMicros: Double = 7 * 24 * 3600 * 1_000_000

    private var fields: [String: Any] = [:]
    private var artwork: ArtworkPayload?
    /// The last timeline decoded, re-anchored when only the play state changes.
    private var timeline: PlaybackTimeline?
    private let clock: () -> Date

    init(clock: @escaping () -> Date = { Date() }) {
        self.clock = clock
    }

    mutating func decode(line: Data) -> Output {
        guard
            let object = try? JSONSerialization.jsonObject(with: line),
            let message = object as? [String: Any],
            message["type"] as? String == "data",
            let payload = message["payload"] as? [String: Any]
        else {
            return .ignored
        }

        let isDiff = (message["diff"] as? NSNumber)?.boolValue ?? false
        if !isDiff {
            fields.removeAll()
            if payload[Key.artworkData] == nil {
                artwork = nil
            }
        }

        for (key, value) in payload {
            if key == Key.artworkData {
                applyArtwork(value)
            } else if value is NSNull {
                fields.removeValue(forKey: key)
            } else {
                fields[key] = value
            }
        }
        // Spotify, turning its playback rate back on, republishes the timestamp alone: the
        // elapsed time is unchanged, so the diff leaves it out. Read literally, the position
        // jumped back to where playback last resumed or was sought (up to tens of seconds)
        // and the lyrics fell behind. A timestamp that comes with a rate change and no
        // position is therefore not fresh timing.
        let hasFreshTiming = !isDiff
            || payload[Key.elapsedTimeMicros] != nil
            || payload[Key.durationMicros] != nil
            || (payload[Key.timestampEpochMicros] != nil && payload[Key.playbackRate] == nil)
        let snapshot = makeSnapshot(hasFreshTiming: hasFreshTiming)
        timeline = snapshot?.timeline
        return .update(snapshot)
    }

    private mutating func applyArtwork(_ value: Any) {
        guard
            let encoded = value as? String,
            let data = Data(base64Encoded: encoded),
            !data.isEmpty
        else {
            artwork = nil
            return
        }
        if artwork?.data == data {
            return
        }
        artwork = ArtworkPayload(id: UUID(), data: data)
    }

    private func makeSnapshot(hasFreshTiming: Bool) -> NowPlayingSnapshot? {
        guard let title = nonEmptyString(Key.title) else {
            return nil
        }
        // Some players (Spotify among them) keep reporting "playing" while paused and only
        // drop their playback rate to 0. When a rate is reported it has the last word:
        // otherwise a paused track looked like it kept playing, its time running out to
        // 0:00, and the next click on the button asked for the wrong thing.
        let flag = (fields[Key.playing] as? NSNumber)?.boolValue ?? false
        let isPlaying = flag && (number(Key.playbackRate).map { $0 != 0 } ?? true)
        return NowPlayingSnapshot(
            bundleIdentifier: nonEmptyString(Key.bundleIdentifier),
            parentBundleIdentifier: nonEmptyString(Key.parentBundleIdentifier),
            title: title,
            artist: nonEmptyString(Key.artist),
            album: nonEmptyString(Key.album),
            isPlaying: isPlaying,
            timeline: makeTimeline(isPlaying: isPlaying, hasFreshTiming: hasFreshTiming),
            artwork: artwork,
            reported: NowPlayingSnapshot.ReportedState(playing: flag, rate: number(Key.playbackRate))
        )
    }

    private func makeTimeline(isPlaying: Bool, hasFreshTiming: Bool) -> PlaybackTimeline? {
        // Live streams report no duration or a sentinel (Twitch in Safari: Int64.max µs,
        // about 292,000 years); anything past a week is treated as live.
        guard let durationMicros = number(Key.durationMicros),
              durationMicros > 0, durationMicros <= Self.longestDurationMicros else {
            return nil
        }
        let duration = durationMicros / 1_000_000
        let reportedRate = number(Key.playbackRate) ?? 1
        let rate = isPlaying ? max(reportedRate, 0.01) : 0

        // A play/pause often arrives on its own, before the player republishes its
        // position. Re-reading the stored elapsed/timestamp pair would then be stale (a
        // resume jumped ahead by the whole pause), so the known position is re-anchored.
        if !hasFreshTiming, let timeline, timeline.duration == duration {
            guard timeline.rate != rate else { return timeline }
            let now = clock()
            return PlaybackTimeline(duration: duration, elapsed: timeline.elapsed(at: now), timestamp: now, rate: rate)
        }

        let timestamp = number(Key.timestampEpochMicros)
            .map { Date(timeIntervalSince1970: $0 / 1_000_000) } ?? clock()
        return PlaybackTimeline(
            duration: duration,
            elapsed: (number(Key.elapsedTimeMicros) ?? 0) / 1_000_000,
            timestamp: timestamp,
            rate: rate
        )
    }

    private func nonEmptyString(_ key: String) -> String? {
        guard let value = fields[key] as? String, !value.isEmpty else { return nil }
        return value
    }

    private func number(_ key: String) -> Double? {
        (fields[key] as? NSNumber)?.doubleValue
    }
}
