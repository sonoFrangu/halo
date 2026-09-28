import Foundation
import Testing
@testable import Halo

struct LRCParserTests {
    @Test func parsesTimestampsAndText() {
        let lines = LRCParser.parse("""
        [ar:Artist]
        [ti:Song]
        [00:12.50]First line
        [00:15.00] Second line
        [01:02.250]Third
        """)
        #expect(lines == [
            LyricLine(time: 12.5, text: "First line"),
            LyricLine(time: 15, text: "Second line"),
            LyricLine(time: 62.25, text: "Third"),
        ])
    }

    @Test func expandsRepeatedTimestampsAndSorts() {
        let lines = LRCParser.parse("[00:30.00][00:10.00]Chorus\n[00:20.00]Verse")
        #expect(lines.map(\.time) == [10, 20, 30])
        #expect(lines.map(\.text) == ["Chorus", "Verse", "Chorus"])
    }

    @Test func acceptsVariants() {
        let lines = LRCParser.parse("[01:05]Minutes only\n[00:07:25]Colon fraction\n[00:09]")
        #expect(lines.map(\.time) == [7.25, 9, 65])
        #expect(lines[1].text.isEmpty)
    }

    @Test func appliesOffset() {
        let lines = LRCParser.parse("[offset:+500]\n[00:10.00]Earlier")
        #expect(lines == [LyricLine(time: 9.5, text: "Earlier")])
    }

    @Test func ignoresGarbage() {
        #expect(LRCParser.parse("no tags here\n[xx:yy]nope\n[00:75.00]bad seconds").isEmpty)
    }
}

struct LyricsTimelineTests {
    private let lines = [
        LyricLine(time: 5, text: "a"),
        LyricLine(time: 10, text: "b"),
        LyricLine(time: 20, text: "c"),
    ]

    @Test func findsTheLineBeingSung() {
        #expect(LyricsTimeline.index(at: 0, in: lines) == nil)
        #expect(LyricsTimeline.index(at: 5, in: lines) == 0)
        #expect(LyricsTimeline.index(at: 9.99, in: lines) == 0)
        #expect(LyricsTimeline.index(at: 10, in: lines) == 1)
        #expect(LyricsTimeline.index(at: 500, in: lines) == 2)
        #expect(LyricsTimeline.index(at: 3, in: []) == nil)
    }

    @Test func schedulesUpcomingLineChanges() {
        let now = Date(timeIntervalSince1970: 1_000)
        let playing = PlaybackTimeline(duration: 60, elapsed: 8, timestamp: now, rate: 1)
        let dates = LyricsTimeline.changeDates(for: lines, timeline: playing, lead: 0, from: now)
        #expect(dates == [now.addingTimeInterval(2), now.addingTimeInterval(12)])

        let early = LyricsTimeline.changeDates(for: lines, timeline: playing, lead: 0.5, from: now)
        #expect(early == [now.addingTimeInterval(1.5), now.addingTimeInterval(11.5)])

        let paused = PlaybackTimeline(duration: 60, elapsed: 8, timestamp: now, rate: 0)
        #expect(LyricsTimeline.changeDates(for: lines, timeline: paused, lead: 0, from: now).isEmpty)
    }

    /// Regression: evaluated exactly at a scheduled change date, the line used to stay on
    /// the previous one whenever rounding landed a hair before the boundary.
    @Test func everyScheduledChangeShowsTheNewLine() {
        let lines = (1...200).map { LyricLine(time: Double($0) * 3.37 + 0.123, text: "\($0)") }
        let now = Date(timeIntervalSinceReferenceDate: 812_345_678.912_345)
        for lead in [0, 0.25, -0.4] {
            let timeline = PlaybackTimeline(duration: 900, elapsed: 1.7, timestamp: now.addingTimeInterval(-0.31), rate: 1)
            let dates = LyricsTimeline.changeDates(for: lines, timeline: timeline, lead: lead, from: now, limit: 512)
            #expect(dates.count == lines.count)
            for (offset, date) in dates.enumerated() {
                let shown = LyricsTimeline.displayedIndex(at: date, in: lines, timeline: timeline, lead: lead)
                #expect(shown == offset, "line \(offset) at lead \(lead)")
            }
        }
    }

    @Test func leadShowsLinesEarly() {
        let now = Date(timeIntervalSince1970: 1_000)
        let timeline = PlaybackTimeline(duration: 60, elapsed: 9.8, timestamp: now, rate: 1)
        #expect(LyricsTimeline.displayedIndex(at: now, in: lines, timeline: timeline, lead: 0) == 0)
        #expect(LyricsTimeline.displayedIndex(at: now, in: lines, timeline: timeline, lead: 0.25) == 1)
    }
}

struct WeatherCodeTests {
    @Test func mapsCodesToSymbols() {
        #expect(WeatherCode.symbol(for: 0, isDay: true) == "sun.max.fill")
        #expect(WeatherCode.symbol(for: 0, isDay: false) == "moon.stars.fill")
        #expect(WeatherCode.symbol(for: 63, isDay: true) == "cloud.rain.fill")
        #expect(WeatherCode.symbol(for: 999, isDay: true) == "cloud.fill")
        #expect(WeatherCode.description(for: 95) == "Temporale")
    }

    @Test func formatsTemperature() {
        let report = WeatherReport(temperature: 21.6, code: 0, isDay: true, usesFahrenheit: false)
        #expect(report.temperatureText == "22°")
    }
}
