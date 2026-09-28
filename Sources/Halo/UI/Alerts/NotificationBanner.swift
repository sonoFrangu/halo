import AppKit
import SwiftUI

/// Banner of a mirrored system notification: app icon, app name, title and body. Clicking
/// opens the app.
struct NotificationBanner: View {
    let alert: NotificationAlert

    var body: some View {
        HStack(spacing: 12) {
            AppIcon(bundleIdentifier: alert.bundleIdentifier)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(alert.appName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .lineLimit(1)
                Text(alert.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let message = alert.body, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
