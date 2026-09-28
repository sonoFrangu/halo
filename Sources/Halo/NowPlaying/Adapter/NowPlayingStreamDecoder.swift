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
        static let artworkData = "artworkData"
    }

    private var fields: [String: Any] = [:]
    private var artwork: ArtworkPayload?
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
        return .update(makeSnapshot())
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

    private func makeSnapshot() -> NowPlayingSnapshot? {
        guard let title = nonEmptyString(Key.title) else {
            return nil
        }
        let isPlaying = (fields[Key.playing] as? NSNumber)?.boolValue ?? false
        return NowPlayingSnapshot(
            bundleIdentifier: nonEmptyString(Key.bundleIdentifier),
            parentBundleIdentifier: nonEmptyString(Key.parentBundleIdentifier),
            title: title,
            artist: nonEmptyString(Key.artist),
            album: nonEmptyString(Key.album),
            isPlaying: isPlaying,
            timeline: makeTimeline(isPlaying: isPlaying),
            artwork: artwork
        )
    }

    private func makeTimeline(isPlaying: Bool) -> PlaybackTimeline? {
        guard let durationMicros = number(Key.durationMicros), durationMicros > 0 else {
            return nil
        }
        let timestamp = number(Key.timestampEpochMicros)
            .map { Date(timeIntervalSince1970: $0 / 1_000_000) } ?? clock()
        let reportedRate = number(Key.playbackRate) ?? 1
        return PlaybackTimeline(
            duration: durationMicros / 1_000_000,
            elapsed: (number(Key.elapsedTimeMicros) ?? 0) / 1_000_000,
            timestamp: timestamp,
            rate: isPlaying ? (reportedRate > 0 ? reportedRate : 1) : 0
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
