/// MediaRemote command IDs, used in-process and by the adapter's `send` command
/// (see the table in Vendor/mediaremote-adapter/README.md). Play and pause are sent
/// explicitly rather than as a toggle, so repeating one never undoes it.
enum MediaCommand: Int, Sendable {
    case play = 0
    case pause = 1
    case nextTrack = 4
    case previousTrack = 5
}
