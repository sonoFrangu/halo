import Foundation

/// A Clock timer event (timers started with Siri or the Clock app).
///
/// Read from Control Center's log messages: `mobiletimerd` accepts only Apple's own
/// clients, and the menu bar timer is not exposed to Accessibility. A pause and a
/// cancellation log the same messages, so both are `.cleared`.
enum SystemTimerEvent: Sendable, Equatable {
    /// The soonest timer runs and ends at `end` (started or resumed).
    case running(id: String, end: Date)
    /// No timer is running any more: paused, cancelled or done.
    case cleared
    case fired(id: String)
}

enum SystemTimerLogParser {
    /// The event a message stands for, or `nil` for everything else.
    static func event(from message: String) -> SystemTimerEvent? {
        if message.hasSuffix("notified next timer changed: (null)") {
            return .cleared
        }
        if let fired = message.range(of: "notified timer fired: ") {
            return .fired(id: message[fired.upperBound...].trimmingCharacters(in: .whitespaces))
        }
        guard
            let trigger = message.range(of: " has next trigger "),
            let open = message.range(of: "date: \"", range: trigger.upperBound..<message.endIndex),
            let close = message.range(of: "\"", range: open.upperBound..<message.endIndex),
            let end = date(from: String(message[open.upperBound..<close.lowerBound]))
        else {
            return nil
        }
        return .running(id: String(message[..<trigger.lowerBound]), end: end)
    }

    /// "Monday, September 28, 2026 at 5:45:28 PM Central European Summer Time". A
    /// formatter per call: events are rare, and `DateFormatter` is not `Sendable`.
    static func date(from text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm:ss a zzzz"
        let plain = text
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
        return formatter.date(from: plain)
    }
}
