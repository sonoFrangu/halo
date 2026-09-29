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
    /// A photo attached to the notification: the first file URL or absolute path anywhere in
    /// the request that names an image. Searched rather than read from one key because the
    /// format is private; a change degrades to no thumbnail.
    var imageURL: URL?

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
            body: text(request["body"]),
            imageURL: imageURL(in: request)
        )
    }

    var isEmpty: Bool {
        title == nil && subtitle == nil && body == nil
    }

    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff"]

    private static func imageURL(in value: Any) -> URL? {
        switch value {
        case let string as String:
            return imageFileURL(string)
        case let dictionary as [String: Any]:
            for key in dictionary.keys.sorted() {
                if let url = dictionary[key].flatMap(imageURL(in:)) { return url }
            }
            return nil
        case let array as [Any]:
            return array.lazy.compactMap(imageURL(in:)).first
        default:
            return nil
        }
    }

    private static func imageFileURL(_ string: String) -> URL? {
        let url: URL
        if string.hasPrefix("file://") {
            guard let parsed = URL(string: string) else { return nil }
            url = parsed
        } else if string.hasPrefix("/") {
            url = URL(fileURLWithPath: string)
        } else {
            return nil
        }
        return imageExtensions.contains(url.pathExtension.lowercased()) ? url : nil
    }

    private static func text(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
