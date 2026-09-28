import Foundation

/// What the player UI asks the playing app to do.
enum PlayerCommand: Sendable, Equatable {
    case play
    case pause
    case nextTrack
    case previousTrack
    case seek(TimeInterval)

    /// The MediaRemote command, for everything but seeking.
    var mediaRemote: MediaCommand? {
        switch self {
        case .play: .play
        case .pause: .pause
        case .nextTrack: .nextTrack
        case .previousTrack: .previousTrack
        case .seek: nil
        }
    }

    /// The keyboard's media key for track skips (play/pause is a toggle, see `MediaKeyPoster`).
    var mediaKey: MediaKey? {
        switch self {
        case .nextTrack: .next
        case .previousTrack: .previous
        case .play, .pause, .seek: nil
        }
    }
}

/// The ways a command can reach the playing app.
enum CommandRoute: String, Sendable, CaseIterable {
    /// Apple Events to Spotify or Music: explicit, immediate, reliable.
    case appleScript = "AppleScript"
    /// MediaRemote called in Halo's own process.
    case direct = "MediaRemote"
    /// MediaRemote through the perl adapter.
    case adapter = "adapter"
    /// The keyboard's play/pause or skip key, pressed on the user's behalf.
    case mediaKey = "media key"

    /// How long a play/pause sent this way may take to show up in the stream.
    var confirmationTimeout: TimeInterval {
        switch self {
        case .appleScript: 1.2
        case .direct: 0.9
        case .adapter: 1.5
        case .mediaKey: 1.0
        }
    }
}

/// Players that take AppleScript commands. MediaRemote commands reach Spotify only
/// intermittently; its (and Music's) scripting interface takes an explicit play or pause
/// and answers within milliseconds.
enum ScriptablePlayer: String, CaseIterable {
    case spotify = "com.spotify.client"
    case music = "com.apple.Music"

    init?(bundleIdentifier: String?) {
        guard let bundleIdentifier else { return nil }
        self.init(rawValue: bundleIdentifier)
    }

    func script(for command: PlayerCommand) -> String {
        let verb: String
        switch command {
        case .play: verb = "play"
        case .pause: verb = "pause"
        case .nextTrack: verb = "next track"
        case .previousTrack: verb = "previous track"
        case .seek(let position): verb = "set player position to " + String(format: "%.3f", max(0, position))
        }
        return "tell application id \"\(rawValue)\" to \(verb)"
    }
}
