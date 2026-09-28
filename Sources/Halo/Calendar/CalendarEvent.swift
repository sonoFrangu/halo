import Foundation

/// A calendar event as the island shows it (a Sendable copy of an `EKEvent`).
struct CalendarEvent: Sendable, Equatable, Identifiable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var color: RGBColor
    var location: String?
    /// Video call link found in the event (Zoom, Meet, Teams, Webex, FaceTime).
    var meetingURL: URL?

    /// Identifies one reminder: a rescheduled event gets a new one.
    var reminderKey: String {
        "\(id)@\(start.timeIntervalSinceReferenceDate)"
    }

    func isOngoing(at date: Date) -> Bool {
        start <= date && date < end
    }
}

/// Finds a video call link in an event's URL, location or notes.
enum MeetingLink {
    private static let patterns = [
        #"https://[\w.-]*zoom\.us/(j|my|w|s)/[^\s<>"']+"#,
        #"https://meet\.google\.com/[a-z]{3,4}-[a-z]{4}-[a-z]{3,4}"#,
        #"https://teams\.microsoft\.com/l/meetup-join/[^\s<>"']+"#,
        #"https://teams\.live\.com/meet/[^\s<>"']+"#,
        #"https://[\w.-]*webex\.com/[^\s<>"']+"#,
        #"https://facetime\.apple\.com/join[^\s<>"']+"#,
    ]

    static func find(in texts: [String?]) -> URL? {
        for text in texts.compactMap({ $0 }) where !text.isEmpty {
            for pattern in patterns {
                guard
                    let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                    let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                    let range = Range(match.range, in: text)
                else { continue }
                let link = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: ".,;:)]}>"))
                if let url = URL(string: link) {
                    return url
                }
            }
        }
        return nil
    }
}

/// When things happen for a list of events. Pure, so the timing rules are testable.
enum CalendarSchedule {
    /// How long before an event its reminder appears.
    static let reminderLead: TimeInterval = 5 * 60
    /// A reminder still appears this long after the start (e.g. the Mac just woke up).
    static let lateReminderGrace: TimeInterval = 60
    /// An event shows in the island header from this long before it starts.
    static let headlineLead: TimeInterval = 60 * 60

    /// Events not over yet, soonest first (ongoing ones lead).
    static func upcoming(_ events: [CalendarEvent], now: Date, limit: Int) -> [CalendarEvent] {
        Array(events.filter { $0.end > now }.sorted { $0.start < $1.start }.prefix(limit))
    }

    /// Events whose reminder is due now and was not shown yet.
    static func dueReminders(_ events: [CalendarEvent], now: Date, alerted: Set<String>) -> [CalendarEvent] {
        events.filter { event in
            !alerted.contains(event.reminderKey)
                && now >= event.start.addingTimeInterval(-reminderLead)
                && now < event.start.addingTimeInterval(lateReminderGrace)
        }
    }

    /// The next moment the display or a reminder changes: the header picks the event up,
    /// its reminder, its start or its end.
    static func nextChange(_ events: [CalendarEvent], after now: Date) -> Date? {
        events
            .flatMap {
                [$0.start.addingTimeInterval(-headlineLead), $0.start.addingTimeInterval(-reminderLead), $0.start, $0.end]
            }
            .filter { $0 > now }
            .min()
    }

    /// The event worth a glance in the island header: ongoing, or starting within the hour.
    static func headline(_ events: [CalendarEvent], now: Date) -> CalendarEvent? {
        upcoming(events, now: now, limit: 1).first { $0.start.timeIntervalSince(now) <= headlineLead }
    }
}
