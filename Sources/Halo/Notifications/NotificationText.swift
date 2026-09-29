import Foundation

/// The lines of a notification banner, Dynamic Island style: a bold headline (usually the
/// sender), a dimmed detail on the same line (the subtitle, e.g. a group chat) and the
/// message under it.
///
/// Apps fill title, subtitle and body inconsistently: some put their own name in the title,
/// some send the sender only as the first line of the body. `make` turns them into lines
/// that read well, and collapses runs of spaces and line breaks.
struct NotificationText: Sendable, Equatable {
    var headline: String
    var detail: String?
    var message: String?

    static func make(title: String?, subtitle: String?, body: String?, appName: String) -> NotificationText {
        let subtitle = clean(subtitle)
        var title = clean(title)
        if let current = title, current.lowercased() == clean(appName)?.lowercased() {
            title = nil
        }
        if let title {
            return NotificationText(headline: title, detail: subtitle, message: clean(body))
        }
        if let subtitle {
            return NotificationText(headline: subtitle, detail: nil, message: clean(body))
        }
        // No title: the body's first line is the headline (often the sender), the rest the message.
        let lines = (body ?? "").split(whereSeparator: \.isNewline).compactMap { clean(String($0)) }
        guard let first = lines.first else {
            return NotificationText(headline: appName, detail: nil, message: nil)
        }
        return NotificationText(headline: first, detail: nil, message: clean(lines.dropFirst().joined(separator: " ")))
    }

    /// Runs of spaces and line breaks become one space; blank text becomes `nil`.
    static func clean(_ text: String?) -> String? {
        guard let text else { return nil }
        let words = text.split(whereSeparator: \.isWhitespace)
        return words.isEmpty ? nil : words.joined(separator: " ")
    }
}
