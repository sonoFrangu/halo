import Foundation

/// MediaRemote called from Halo's own process: a command reaches the player within a
/// millisecond, instead of the fraction of a second it takes to launch the adapter.
///
/// Since macOS 15.4 MediaRemote refuses to *report* what is playing to apps outside
/// Apple's allow list (hence the adapter), while commands have kept working for them.
/// That is not documented, so `NowPlayingController` checks every play/pause sent this
/// way against the adapter's stream and switches to the adapter for good when one has
/// no effect.
@MainActor
final class DirectMediaRemote {
    private typealias SendCommand = @convention(c) (Int32, CFDictionary?) -> Bool
    private typealias SetElapsedTime = @convention(c) (Double) -> Void

    private let sendCommand: SendCommand?
    private let setElapsedTime: SetElapsedTime?

    init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY)
        sendCommand = handle
            .flatMap { dlsym($0, "MRMediaRemoteSendCommand") }
            .map { unsafeBitCast($0, to: SendCommand.self) }
        setElapsedTime = handle
            .flatMap { dlsym($0, "MRMediaRemoteSetElapsedTime") }
            .map { unsafeBitCast($0, to: SetElapsedTime.self) }
        if sendCommand == nil {
            Log.adapter.info("MediaRemote commands unavailable in-process; using the adapter")
        }
    }

    /// `false` when the function is missing or MediaRemote rejected the command outright.
    /// `true` does not prove the player received it.
    func send(_ command: MediaCommand) -> Bool {
        sendCommand?(Int32(command.rawValue), nil) ?? false
    }

    func seek(to position: TimeInterval) -> Bool {
        guard let setElapsedTime else { return false }
        setElapsedTime(max(0, position))
        return true
    }
}
