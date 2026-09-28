import Foundation

/// Runs AppleScript commands one at a time on a private queue, so a player slow to answer
/// (or the one-time "Halo wants to control Spotify" prompt) never blocks the main thread.
final class ScriptRunner: Sendable {
    /// Apple Events refused because the user denied Halo control of the app.
    static let notPermitted = -1743

    private let queue = DispatchQueue(label: "io.github.sonofrangu.halo.applescript", qos: .userInitiated)

    /// The AppleScript error number, `nil` on success.
    func run(_ source: String) async -> Int? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard let script = NSAppleScript(source: source) else {
                    continuation.resume(returning: -2700)
                    return
                }
                var error: NSDictionary?
                _ = script.executeAndReturnError(&error)
                let code = error.map { ($0[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? -2700 }
                continuation.resume(returning: code)
            }
        }
    }

    /// Loads the AppleScript machinery before the first real command (no Apple Event is
    /// sent, so no prompt appears).
    func prewarm() {
        queue.async {
            _ = NSAppleScript(source: "return 0")?.executeAndReturnError(nil)
        }
    }
}
