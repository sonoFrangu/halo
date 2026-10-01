import AppKit
import SwiftUI

/// Banner of a mirrored system notification, Dynamic Island style: app icon, sender with the
/// group or subtitle dimmed beside it, up to two lines of message, and on the right the
/// attached photo or "ora". Notifications stacked from the same app put their count on the
/// icon, like an app badge. Clicking opens the app.
struct NotificationBanner: View {
    let alert: NotificationAlert

    var body: some View {
        let text = alert.text
        let corner = RoundedRectangle(cornerRadius: Corner.tile, style: .continuous)

        HStack(spacing: 12) {
            AppIcon(bundleIdentifier: alert.bundleIdentifier)
                .frame(width: 44, height: 44)
                .clipShape(corner)
                .overlay(alignment: .topTrailing) {
                    if alert.count > 1 {
                        CountBadge(count: alert.count)
                            .offset(x: 6, y: -6)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text(text.headline)
                        .font(Typography.headline)
                        .foregroundStyle(.white)
                        .layoutPriority(1)
                    if let detail = text.detail {
                        Text(" · \(detail)")
                            .font(Typography.body)
                            .foregroundStyle(Ink.secondary)
                    }
                }
                .lineLimit(1)

                if let message = text.message {
                    Text(message)
                        .font(Typography.body)
                        .foregroundStyle(Ink.primary)
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
                    .font(Typography.subheadline)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Red count on an app icon, as on the Dock and the Home Screen.
private struct CountBadge: View {
    let count: Int

    var body: some View {
        Text(count, format: .number)
            .font(Typography.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .frame(minWidth: 18, minHeight: 18)
            .background(Color.red, in: Capsule())
            .accessibilityLabel("\(count) notifiche")
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
            RoundedRectangle(cornerRadius: Corner.tile, style: .continuous)
                .fill(Fill.primary)
                .overlay {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(Ink.secondary)
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
