import AppKit
import SwiftUI

/// Banner of a mirrored system notification, Dynamic Island style: app icon, sender with the
/// group or subtitle dimmed beside it, up to two lines of message, and on the right the
/// attached photo or "ora". Clicking opens the app.
struct NotificationBanner: View {
    let alert: NotificationAlert

    var body: some View {
        let text = alert.text
        let corner = RoundedRectangle(cornerRadius: 10, style: .continuous)

        HStack(spacing: 12) {
            AppIcon(bundleIdentifier: alert.bundleIdentifier)
                .frame(width: 44, height: 44)
                .clipShape(corner)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text(text.headline)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .layoutPriority(1)
                    if let detail = text.detail {
                        Text(" · \(detail)")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .lineLimit(1)

                if let message = text.message {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let thumbnail = NotificationThumbnail.cached(alert.id) {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(corner)
                    .accessibilityLabel("Foto")
            } else {
                Text("ora")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Icon of an installed app, cached by bundle identifier.
struct AppIcon: View {
    let bundleIdentifier: String

    var body: some View {
        if let image = AppIconCache.icon(for: bundleIdentifier) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .overlay {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.white.opacity(0.6))
                }
        }
    }
}

@MainActor
enum AppIconCache {
    private static var icons: [String: NSImage] = [:]

    static func icon(for bundleIdentifier: String) -> NSImage? {
        if let cached = icons[bundleIdentifier] {
            return cached
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[bundleIdentifier] = icon
        return icon
    }
}
