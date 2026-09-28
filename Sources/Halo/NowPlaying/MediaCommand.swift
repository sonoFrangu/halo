/// MediaRemote command IDs accepted by the adapter's `send` command
/// (see the table in Vendor/mediaremote-adapter/README.md).
enum MediaCommand: Int, Sendable {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case nextTrack = 4
    case previousTrack = 5
}
