import Foundation

/// The visible text of a delivered notification, decoded from the binary property list
/// Notification Center stores for each record (`record.data`).
///
/// The format is private: a dictionary whose `req` entry holds the request, with the title
/// under `titl`, the subtitle under `subt` and the message under `body`. Unknown or missing
/// keys decode to `nil` rather than failing, so a format change degrades to a banner with
/// only the app name instead of wrong text.
struct NotificationPayload: Sendable, Equatable {
    var title: String?
    var subtitle: String?
    var body: String?

    /// `nil` when the data is not a property list with a request dictionary.
    static func parse(_ data: Data) -> NotificationPayload? {
        guard
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let root = plist as? [String: Any],
            let request = root["req"] as? [String: Any]
        else { return nil }

        return NotificationPayload(
            title: text(request["titl"]),
            subtitle: text(request["subt"]),
            body: text(request["body"])
        )
    }

    /// The banner's second line: subtitle and message together when both exist.
    var message: String? {
        switch (subtitle, body) {
        case let (subtitle?, body?): "\(subtitle) · \(body)"
        case let (subtitle?, nil): subtitle
        case let (nil, body?): body
        case (nil, nil): nil
        }
    }

    var isEmpty: Bool {
        title == nil && subtitle == nil && body == nil
    }

    private static func text(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
