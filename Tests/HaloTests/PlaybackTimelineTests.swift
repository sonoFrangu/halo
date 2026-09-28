import Foundation
import Testing
@testable import Halo

struct PlaybackTimelineTests {
    private let start = Date(timeIntervalSince1970: 1_000)

    @Test func advancesWithRateAndClamps() {
        let timeline = PlaybackTimeline(duration: 100, elapsed: 10, timestamp: start, rate: 1)
        #expect(timeline.elapsed(at: start.addingTimeInterval(5)) == 15)
        #expect(timeline.elapsed(at: start.addingTimeInterval(500)) == 100)
        #expect(timeline.elapsed(at: start.addingTimeInterval(-5)) == 10)
        #expect(timeline.progress(at: start.addingTimeInterval(40)) == 0.5)
        #expect(timeline.remaining(at: start.addingTimeInterval(40)) == 50)
    }

    @Test func pausedTimelineIsFrozen() {
        let timeline = PlaybackTimeline(duration: 100, elapsed: 10, timestamp: start, rate: 0)
        #expect(timeline.elapsed(at: start.addingTimeInterval(30)) == 10)
        #expect(!timeline.isAdvancing)
    }

    @Test func togglingReanchorsAtCurrentPosition() {
        let playing = PlaybackTimeline(duration: 100, elapsed: 10, timestamp: start, rate: 1)
        let now = start.addingTimeInterval(20)
        let paused = playing.settingPlaying(false, at: now)
        #expect(paused.elapsed(at: now.addingTimeInterval(10)) == 30)
        let resumed = paused.settingPlaying(true, at: now.addingTimeInterval(10))
        #expect(resumed.elapsed(at: now.addingTimeInterval(15)) == 35)
    }

    @Test func seekingClampsToDuration() {
        let timeline = PlaybackTimeline(duration: 100, elapsed: 10, timestamp: start, rate: 1)
        #expect(timeline.seeking(to: 250, at: start).elapsed(at: start) == 100)
        #expect(timeline.seeking(to: -3, at: start).elapsed(at: start) == 0)
    }

    @Test func formatsTimes() {
        #expect(TimeFormatting.string(0) == "0:00")
        #expect(TimeFormatting.string(65.9) == "1:05")
        #expect(TimeFormatting.string(3_725) == "1:02:05")
        #expect(TimeFormatting.string(.nan) == "--:--")
        #expect(TimeFormatting.string(-1) == "--:--")
    }
}
