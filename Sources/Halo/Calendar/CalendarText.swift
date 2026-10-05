import Foundation

/// Italian wording of event times: "tra 12 min", "in corso · fino alle 11:15", "domani 9:30".
enum CalendarText {
    static func relative(to start: Date, now: Date) -> String? {
        let minutes = Int((start.timeIntervalSince(now) / 60).rounded(.up))
        switch minutes {
        case ...0: return "adesso"
        case 1..<60: return "tra \(minutes) min"
        default: return nil
        }
    }

    /// Second line of an event row.
    static func subtitle(for event: CalendarEvent, now: Date, calendar: Calendar = .current) -> String {
        if event.isOngoing(at: now) {
            return "In corso · fino alle \(time(event.end))"
        }
        if event.isAllDay, event.start <= now {
            return "Tutto il giorno"
        }
        let range = event.isAllDay ? "tutto il giorno" : "\(time(event.start)) – \(time(event.end))"
        if !event.isAllDay, let relative = relative(to: event.start, now: now) {
            return "\(relative.prefix(1).uppercased())\(relative.dropFirst()) · \(range)"
        }
        if calendar.isDate(event.start, inSameDayAs: now) {
            return range
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(event.start, inSameDayAs: tomorrow) {
            return "Domani · \(range)"
        }
        return "\(event.start.formatted(.dateTime.weekday(.wide))) · \(range)"
    }

    /// Short form for the island header and the reminder banner.
    static func short(for event: CalendarEvent, now: Date) -> String {
        if event.isOngoing(at: now) {
            return "in corso"
        }
        return relative(to: event.start, now: now) ?? time(event.start)
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
