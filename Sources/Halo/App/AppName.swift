import AppKit

/// Display name of an installed app from its bundle identifier ("Spotify", not
/// "com.spotify.client"), cached; the identifier itself when the app is not installed.
@MainActor
enum AppName {
    private static var names: [String: String] = [:]

    static func of(_ bundleIdentifier: String) -> String {
        if let cached = names[bundleIdentifier] {
            return cached
        }
        var name = bundleIdentifier
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let display = FileManager.default.displayName(atPath: url.path)
            name = display.hasSuffix(".app") ? String(display.dropLast(4)) : display
        }
        names[bundleIdentifier] = name
        return name
    }
}
