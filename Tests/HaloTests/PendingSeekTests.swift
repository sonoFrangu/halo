import Foundation
import Testing
@testable import Halo

/// Timings measured on Spotify: the seek is echoed at once, and when the audio has to load
/// the restart is reported about 1.1 s later from the sought position.
struct PendingSeekTests {
    private let start = Date(timeIntervalSince1970: 1_000)
    private var playing: PlaybackTimeline { PlaybackTimeline(duration: 200, elapsed: 33, timestamp: start, rate: 1) }

    private func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }

    @Test func spotifyHoldsTheSoughtPositionUntilItRestarts() {
        let seek = PendingSeek(title: "t", from: playing, to: 79.5, player: "com.spotify.client", at: start)
        let echo = PlaybackTimeline(duration: 200, elapsed: 79.5, timestamp: at(0.02), rate: 1)
        #expect(!seek.isConfirmed(by: echo, at: at(0.05)))
        #expect(seek.held(at: at(1), isPlaying: true).elapsed(at: at(1)) == 79.5)

        let restart = PlaybackTimeline(duration: 200, elapsed: 79.55, timestamp: at(1.1), rate: 1)
        #expect(seek.isConfirmed(by: restart, at: at(1.1)))
    }

    @Test func spotifyTakesTheEchoWhenTheAudioWasLoaded() {
        let seek = PendingSeek(title: "t", from: playing, to: 50, player: "com.spotify.client", at: start)
        let echo = PlaybackTimeline(duration: 200, elapsed: 50, timestamp: at(0.02), rate: 1)
        #expect(!seek.isConfirmed(by: echo, at: at(1)))
        #expect(seek.isConfirmed(by: echo, at: at(PendingSeek.loadAllowance)))
    }

    @Test func otherPlayersAdvanceAtOnce() {
        let seek = PendingSeek(title: "t", from: playing, to: 120, player: "com.apple.Music", at: start)
        #expect(!seek.waitsForLoad)
        #expect(abs(seek.held(at: at(0.4), isPlaying: true).elapsed(at: at(0.4)) - 120.4) < 0.001)
        #expect(seek.isConfirmed(by: PlaybackTimeline(duration: 200, elapsed: 120, timestamp: at(0.05), rate: 1), at: at(0.1)))
    }

    @Test func theOldPositionNeverConfirms() {
        let seek = PendingSeek(title: "t", from: playing, to: 120, player: "com.spotify.client", at: start)
        #expect(!seek.isConfirmed(by: PlaybackTimeline(duration: 200, elapsed: 34, timestamp: at(0.8), rate: 1), at: at(2)))
    }
}
