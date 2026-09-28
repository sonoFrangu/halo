import Foundation

/// One timed line of synced lyrics.
struct LyricLine: Sendable, Equatable, Hashable {
    /// Seconds from the start of the track.
    var time: TimeInterval
    /// Empty for instrumental breaks.
    var text: String
}

/// Parses LRC ("[mm:ss.xx] text") into time-sorted lines.
///
/// Handles several timestamps on one line (`[00:12.00][01:30.50]Chorus`), minute-only
/// precision, two- or three-digit fractions, the `mm:ss:xx` variant, metadata tags
/// (`[ar:…]`, ignored) and the `[offset:±ms]` tag (positive shows lyrics earlier).
enum LRCParser {
    static func parse(_ text: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        var offset: TimeInterval = 0

        for rawLine in text.split(whereSeparator: \.isNewline) {
            var rest = Substring(rawLine).trimmingCharacters(in: .whitespaces)[...]
            var times: [TimeInterval] = []

            while rest.hasPrefix("["), let close = rest.firstIndex(of: "]") {
                let tag = rest[rest.index(after: rest.startIndex)..<close]
                rest = rest[rest.index(after: close)...]
                if let time = timestamp(tag) {
                    times.append(time)
                } else if tag.lowercased().hasPrefix("offset:"), let value = Double(tag.dropFirst(7).trimmingCharacters(in: .whitespaces)) {
                    offset = value / 1000
                }
            }

            let lyric = rest.trimmingCharacters(in: .whitespaces)
            for time in times {
                lines.append(LyricLine(time: time, text: lyric))
            }
        }

        return lines
            .map { LyricLine(time: max(0, $0.time - offset), text: $0.text) }
            .sorted { $0.time < $1.time }
    }

    /// `mm:ss`, `mm:ss.xx`, `mm:ss.xxx` or `mm:ss:xx`.
    private static func timestamp(_ tag: Substring) -> TimeInterval? {
        let parts = tag.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3, let minutes = Int(parts[0]), minutes >= 0 else {
            return nil
        }
        let secondsPart: Substring
        let fractionPart: Substring?
        if parts.count == 3 {
            secondsPart = parts[1]
            fractionPart = parts[2]
        } else if let dot = parts[1].firstIndex(of: ".") {
            secondsPart = parts[1][..<dot]
            fractionPart = parts[1][parts[1].index(after: dot)...]
        } else {
            secondsPart = parts[1]
            fractionPart = nil
        }
        guard let seconds = Int(secondsPart), (0..<60).contains(seconds) else { return nil }
        var fraction: TimeInterval = 0
        if let fractionPart, !fractionPart.isEmpty {
            guard let digits = Int(fractionPart), digits >= 0 else { return nil }
            fraction = TimeInterval(digits) / pow(10, TimeInterval(fractionPart.count))
        }
        return TimeInterval(minutes * 60 + seconds) + fraction
    }
}

/// Where playback is within the lyrics.
enum LyricsTimeline {
    /// Index of the line being sung at `elapsed`, or `nil` before the first line.
    static func index(at elapsed: TimeInterval, in lines: [LyricLine]) -> Int? {
        var low = 0
        var high = lines.count - 1
        var found: Int?
        while low <= high {
            let middle = (low + high) / 2
            if lines[middle].time <= elapsed {
                found = middle
                low = middle + 1
            } else {
                high = middle - 1
            }
        }
        return found
    }

    /// Wall-clock moments at which the current line changes, from `now` on. Feeding them to
    /// an explicit `TimelineView` schedule redraws the lyrics exactly on line changes.
    static func changeDates(for lines: [LyricLine], timeline: PlaybackTimeline, from now: Date, limit: Int = 64) -> [Date] {
        guard timeline.isAdvancing, timeline.rate > 0 else { return [] }
        let elapsed = timeline.elapsed(at: now)
        var dates: [Date] = []
        for line in lines where line.time > elapsed {
            dates.append(now.addingTimeInterval((line.time - elapsed) / timeline.rate))
            if dates.count == limit { break }
        }
        return dates
    }
}
