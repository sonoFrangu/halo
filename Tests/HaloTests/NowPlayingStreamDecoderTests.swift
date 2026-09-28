import Foundation
import Testing
@testable import Halo

struct NowPlayingStreamDecoderTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var fullPayload: [String: Any] {
        [
            "bundleIdentifier": "com.spotify.client",
            "playing": true,
            "title": "Song",
            "artist": "Artist",
            "album": "Album",
            "durationMicros": 200_000_000,
            "elapsedTimeMicros": 50_000_000,
            "timestampEpochMicros": 1_800_000_000_000_000,
            "playbackRate": 1,
        ]
    }

    private func makeDecoder() -> NowPlayingStreamDecoder {
        let now = self.now
        return NowPlayingStreamDecoder(clock: { now })
    }

    private func line(diff: Bool, _ payload: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["type": "data", "diff": diff, "payload": payload])
    }

    /// Decodes and unwraps an `.update`, recording an issue for anything else.
    private func decode(
        _ decoder: inout NowPlayingStreamDecoder,
        diff: Bool,
        _ payload: [String: Any]
    ) throws -> NowPlayingSnapshot? {
        let output = decoder.decode(line: try line(diff: diff, payload))
        guard case .update(let snapshot) = output else {
            Issue.record("expected an update, got \(output)")
            return nil
        }
        return snapshot
    }

    @Test func decodesFullPayload() throws {
        var decoder = makeDecoder()
        let decoded = try decode(&decoder, diff: false, fullPayload)
        let result = try #require(decoded)
        #expect(result.title == "Song")
        #expect(result.artist == "Artist")
        #expect(result.album == "Album")
        #expect(result.bundleIdentifier == "com.spotify.client")
        #expect(result.isPlaying)
        let timeline = try #require(result.timeline)
        #expect(timeline.duration == 200)
        #expect(timeline.elapsed == 50)
        #expect(timeline.rate == 1)
        #expect(timeline.timestamp == now)
    }

    @Test func appliesDiffsAndNullRemovals() throws {
        var decoder = makeDecoder()
        _ = try decode(&decoder, diff: false, fullPayload)
        let decoded = try decode(&decoder, diff: true, ["playing": false, "artist": NSNull()])
        let paused = try #require(decoded)
        #expect(paused.title == "Song")
        #expect(paused.isPlaying == false)
        #expect(paused.artist == nil)
        #expect(paused.timeline?.rate == 0)
    }

    @Test func emptyPayloadMeansNothingPlaying() throws {
        var decoder = makeDecoder()
        _ = try decode(&decoder, diff: false, fullPayload)
        let output = decoder.decode(line: try line(diff: false, [:]))
        #expect(output == .update(nil))
    }

    @Test func missingTitleMeansNothingPlaying() throws {
        var decoder = makeDecoder()
        let output = decoder.decode(line: try line(diff: false, ["playing": true, "bundleIdentifier": "x"]))
        #expect(output == .update(nil))
    }

    @Test func ignoresInvalidAndForeignLines() throws {
        var decoder = makeDecoder()
        let garbage = decoder.decode(line: Data("not json".utf8))
        let null = decoder.decode(line: Data("null".utf8))
        let foreign = decoder.decode(
            line: try JSONSerialization.data(withJSONObject: ["type": "log", "payload": [String: Any]()])
        )
        #expect(garbage == .ignored)
        #expect(null == .ignored)
        #expect(foreign == .ignored)
    }

    @Test func decodesArtworkOncePerDistinctImage() throws {
        var decoder = makeDecoder()
        let bytes = Data([0x89, 0x50, 0x4E, 0x47, 0x01, 0x02])
        var payload = fullPayload
        payload["artworkData"] = bytes.base64EncodedString()

        let firstOutput = try decode(&decoder, diff: false, payload)
        let first = try #require(firstOutput)
        let artwork = try #require(first.artwork)
        #expect(artwork.data == bytes)

        let elapsedOutput = try decode(&decoder, diff: true, ["elapsedTimeMicros": 60_000_000])
        let elapsed = try #require(elapsedOutput)
        #expect(elapsed.artwork?.id == artwork.id)

        let resentOutput = try decode(&decoder, diff: false, payload)
        let resent = try #require(resentOutput)
        #expect(resent.artwork?.id == artwork.id)

        let removedOutput = try decode(&decoder, diff: true, ["artworkData": NSNull()])
        let removed = try #require(removedOutput)
        #expect(removed.artwork == nil)
    }

    @Test func fullPayloadWithoutArtworkClearsIt() throws {
        var decoder = makeDecoder()
        var payload = fullPayload
        payload["artworkData"] = Data([1, 2, 3]).base64EncodedString()
        _ = try decode(&decoder, diff: false, payload)
        let nextOutput = try decode(&decoder, diff: false, fullPayload)

        let next = try #require(nextOutput)
        #expect(next.artwork == nil)
    }

    @Test func prefersParentApplicationAsSource() throws {
        var decoder = makeDecoder()
        var payload = fullPayload
        payload["bundleIdentifier"] = "com.apple.WebKit.GPU"
        payload["parentApplicationBundleIdentifier"] = "com.apple.Safari"
        let resultOutput = try decode(&decoder, diff: false, payload)

        let result = try #require(resultOutput)
        #expect(result.sourceBundleIdentifier == "com.apple.Safari")
    }

    @Test func liveContentHasNoTimeline() throws {
        var decoder = makeDecoder()
        var payload = fullPayload
        payload["durationMicros"] = 0
        let resultOutput = try decode(&decoder, diff: false, payload)

        let result = try #require(resultOutput)
        #expect(result.timeline == nil)
    }
}
