import CoreAudio
import CoreMediaIO
import Foundation
import Observation

/// Whether any app is using a microphone or a camera, like the dots on iPhone.
///
/// Event driven: CoreAudio and CoreMediaIO call back when a device starts or stops
/// "running somewhere" (in any process) and when devices come and go. Reading these
/// properties needs no permission and never turns a device on.
@MainActor
@Observable
final class PrivacyIndicators {
    enum Kind: Sendable, Equatable {
        case microphone
        case camera
    }

    private(set) var isMicrophoneInUse = false
    private(set) var isCameraInUse = false
    private(set) var isEnabled = Preferences.privacyIndicatorEnabled

    /// What the island shows: the camera wins, as on iPhone.
    var active: Kind? {
        if isCameraInUse { return .camera }
        if isMicrophoneInUse { return .microphone }
        return nil
    }

    @ObservationIgnored private var audioListeners: [AudioListener] = []
    @ObservationIgnored private var cameraListeners: [CameraListener] = []

    func start() {
        guard isEnabled, audioListeners.isEmpty, cameraListeners.isEmpty else { return }
        rewatch()
    }

    func stop() {
        audioListeners.forEach { $0.remove() }
        cameraListeners.forEach { $0.remove() }
        audioListeners.removeAll()
        cameraListeners.removeAll()
        isMicrophoneInUse = false
        isCameraInUse = false
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.privacyIndicatorEnabled = enabled
        if enabled { start() } else { stop() }
    }

    // MARK: Watching

    /// (Re)registers on the device lists and on every input device and camera.
    private func rewatch() {
        audioListeners.forEach { $0.remove() }
        cameraListeners.forEach { $0.remove() }

        let changed: @MainActor @Sendable () -> Void = { [weak self] in self?.refresh() }
        let devicesChanged: @MainActor @Sendable () -> Void = { [weak self] in self?.rewatch() }

        var audio = [AudioListener(object: AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyDevices, action: devicesChanged)]
        audio += Self.audioInputDevices().map {
            AudioListener(object: $0, selector: kAudioDevicePropertyDeviceIsRunningSomewhere, action: changed)
        }
        var cameras = [CameraListener(object: CMIOObjectID(kCMIOObjectSystemObject), selector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices), action: devicesChanged)]
        cameras += Self.cameras().map {
            CameraListener(object: $0, selector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere), action: changed)
        }
        audioListeners = audio.compactMap { $0 }
        cameraListeners = cameras.compactMap { $0 }
        refresh()
    }

    private func refresh() {
        let microphone = Self.audioInputDevices().contains { Self.isRunning(audioDevice: $0) }
        let camera = Self.cameras().contains { Self.isRunning(camera: $0) }
        if microphone != isMicrophoneInUse { isMicrophoneInUse = microphone }
        if camera != isCameraInUse { isCameraInUse = camera }
    }

    // MARK: CoreAudio

    private static func audioAddress(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    /// Devices with at least one input stream.
    private static func audioInputDevices() -> [AudioObjectID] {
        var address = audioAddress(kAudioHardwarePropertyDevices)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var devices = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &devices) == noErr else { return [] }
        return devices.filter { device in
            var streams = audioAddress(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)
            var streamsSize: UInt32 = 0
            return AudioObjectGetPropertyDataSize(device, &streams, 0, nil, &streamsSize) == noErr && streamsSize > 0
        }
    }

    private static func isRunning(audioDevice: AudioObjectID) -> Bool {
        var address = audioAddress(kAudioDevicePropertyDeviceIsRunningSomewhere)
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(audioDevice, &address, 0, nil, &size, &running) == noErr && running != 0
    }

    // MARK: CoreMediaIO

    private static func cmioAddress(_ selector: CMIOObjectPropertySelector) -> CMIOObjectPropertyAddress {
        CMIOObjectPropertyAddress(
            mSelector: selector,
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
    }

    private static func cameras() -> [CMIOObjectID] {
        var address = cmioAddress(CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices))
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &devices) == noErr else { return [] }
        return devices
    }

    private static func isRunning(camera: CMIOObjectID) -> Bool {
        var address = cmioAddress(CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere))
        var running: UInt32 = 0
        var used: UInt32 = 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        return CMIOObjectGetPropertyData(camera, &address, 0, nil, size, &used, &running) == noErr && running != 0
    }
}

/// A CoreAudio property listener that calls `action` on the main actor.
@MainActor
private struct AudioListener {
    let object: AudioObjectID
    let selector: AudioObjectPropertySelector
    let block: AudioObjectPropertyListenerBlock

    init?(object: AudioObjectID, selector: AudioObjectPropertySelector, action: @escaping @MainActor @Sendable () -> Void) {
        let block: AudioObjectPropertyListenerBlock = { _, _ in
            MainActor.assumeIsolated {
                action()
            }
        }
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectAddPropertyListenerBlock(object, &address, DispatchQueue.main, block) == noErr else { return nil }
        self.object = object
        self.selector = selector
        self.block = block
    }

    func remove() {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectRemovePropertyListenerBlock(object, &address, DispatchQueue.main, block)
    }
}

/// A CoreMediaIO property listener that calls `action` on the main actor.
@MainActor
private struct CameraListener {
    let object: CMIOObjectID
    let selector: CMIOObjectPropertySelector
    let block: CMIOObjectPropertyListenerBlock

    init?(object: CMIOObjectID, selector: CMIOObjectPropertySelector, action: @escaping @MainActor @Sendable () -> Void) {
        let block: CMIOObjectPropertyListenerBlock = { _, _ in
            MainActor.assumeIsolated {
                action()
            }
        }
        var address = CMIOObjectPropertyAddress(
            mSelector: selector,
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        guard CMIOObjectAddPropertyListenerBlock(object, &address, DispatchQueue.main, block) == noErr else { return nil }
        self.object = object
        self.selector = selector
        self.block = block
    }

    func remove() {
        var address = CMIOObjectPropertyAddress(
            mSelector: selector,
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        CMIOObjectRemovePropertyListenerBlock(object, &address, DispatchQueue.main, block)
    }
}
