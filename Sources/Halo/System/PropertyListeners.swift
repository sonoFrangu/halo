import CoreAudio
import CoreMediaIO
import Foundation

// CoreAudio and CoreMediaIO listeners registered through the function-pointer API, removed
// when the listener is released.
//
// The block API cannot be used from Swift: every call bridges the closure into a new block,
// so `AudioObjectRemovePropertyListenerBlock` never finds the one registered and returns
// noErr anyway. Listeners piled up, each device change re-registered them all, and the
// privacy watcher burned seconds of CPU on every device change (verified on macOS 27 by
// creating a temporary aggregate device: a "removed" block kept firing).

/// A CoreAudio property listener that calls `action` on `queue` until released.
final class AudioPropertyListener: Sendable {
    private let object: AudioObjectID
    private let address: AudioObjectPropertyAddress
    private let queue: DispatchQueue
    private let action: @Sendable () -> Void

    init?(
        object: AudioObjectID,
        selector: AudioObjectPropertySelector,
        queue: DispatchQueue,
        action: @escaping @Sendable () -> Void
    ) {
        self.object = object
        self.address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        self.queue = queue
        self.action = action
        var address = address
        guard AudioObjectAddPropertyListener(object, &address, Self.proc, Unmanaged.passUnretained(self).toOpaque()) == noErr else {
            return nil
        }
    }

    deinit {
        var address = address
        AudioObjectRemovePropertyListener(object, &address, Self.proc, Unmanaged.passUnretained(self).toOpaque())
    }

    private static let proc: AudioObjectPropertyListenerProc = { _, _, _, context in
        guard let context else { return noErr }
        let listener = Unmanaged<AudioPropertyListener>.fromOpaque(context).takeUnretainedValue()
        listener.queue.async(execute: listener.action)
        return noErr
    }
}

/// A CoreMediaIO property listener that calls `action` on `queue` until released.
final class CameraPropertyListener: Sendable {
    private let object: CMIOObjectID
    private let address: CMIOObjectPropertyAddress
    private let queue: DispatchQueue
    private let action: @Sendable () -> Void

    init?(
        object: CMIOObjectID,
        selector: CMIOObjectPropertySelector,
        queue: DispatchQueue,
        action: @escaping @Sendable () -> Void
    ) {
        self.object = object
        self.address = CMIOObjectPropertyAddress(
            mSelector: selector,
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        self.queue = queue
        self.action = action
        var address = address
        guard CMIOObjectAddPropertyListener(object, &address, Self.proc, Unmanaged.passUnretained(self).toOpaque()) == noErr else {
            return nil
        }
    }

    deinit {
        var address = address
        CMIOObjectRemovePropertyListener(object, &address, Self.proc, Unmanaged.passUnretained(self).toOpaque())
    }

    private static let proc: CMIOObjectPropertyListenerProc = { _, _, _, context in
        guard let context else { return noErr }
        let listener = Unmanaged<CameraPropertyListener>.fromOpaque(context).takeUnretainedValue()
        listener.queue.async(execute: listener.action)
        return noErr
    }
}
