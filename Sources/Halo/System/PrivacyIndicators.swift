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

    @ObservationIgnored private var watcher: DeviceUsageWatcher?
    /// Tells a stopped watcher's late report from the current one's.
    @ObservationIgnored private var generation = 0

    func start() {
        guard isEnabled, watcher == nil else { return }
        generation += 1
        let generation = generation
        let watcher = DeviceUsageWatcher { [weak self] microphone, camera in
            Task { @MainActor in
                self?.apply(microphone: microphone, camera: camera, generation: generation)
            }
        }
        watcher.start()
        self.watcher = watcher
    }

    func stop() {
        watcher?.stop()
        watcher = nil
        isMicrophoneInUse = false
        isCameraInUse = false
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.privacyIndicatorEnabled = enabled
        if enabled { start() } else { stop() }
    }

    private func apply(microphone: Bool, camera: Bool, generation: Int) {
        guard watcher != nil, generation == self.generation else { return }
        if microphone != isMicrophoneInUse { isMicrophoneInUse = microphone }
        if camera != isCameraInUse { isCameraInUse = camera }
    }
}

/// Watches the devices on a private serial queue. CoreAudio and above all CoreMediaIO
/// calls can block for seconds (Continuity Camera devices appearing after wake, a DAL
/// plug-in loading), so none of them runs on the main thread: a stalled main thread leaves
/// the lock screen card on screen after unlocking and times out the media key tap.
///
/// `@unchecked Sendable`: every mutable property is touched only on `queue`.
private final class DeviceUsageWatcher: @unchecked Sendable {
    private let queue = DispatchQueue(label: "io.github.sonofrangu.halo.privacy", qos: .utility)
    private let report: @Sendable (_ microphone: Bool, _ camera: Bool) -> Void
    private var audioListeners: [AudioPropertyListener] = []
    private var cameraListeners: [CameraPropertyListener] = []
    private var last: (microphone: Bool, camera: Bool)?
    private var isStopped = false

    init(report: @escaping @Sendable (_ microphone: Bool, _ camera: Bool) -> Void) {
        self.report = report
    }

    func start() {
        queue.async { self.rewatch() }
    }

    func stop() {
        queue.async {
            self.isStopped = true
            self.removeListeners()
        }
    }

    /// Released listeners unregister themselves.
    private func removeListeners() {
        audioListeners.removeAll()
        cameraListeners.removeAll()
    }

    /// (Re)registers on the device lists and on every input device and camera.
    private func rewatch() {
        guard !isStopped else { return }
        removeListeners()
        let changed: @Sendable () -> Void = { [weak self] in self?.refresh() }
        let devicesChanged: @Sendable () -> Void = { [weak self] in self?.rewatch() }

        var audio = [AudioPropertyListener(object: AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyDevices, queue: queue, action: devicesChanged)]
        audio += Self.audioInputDevices().map {
            AudioPropertyListener(object: $0, selector: kAudioDevicePropertyDeviceIsRunningSomewhere, queue: queue, action: changed)
        }
        var cameras = [CameraPropertyListener(object: CMIOObjectID(kCMIOObjectSystemObject), selector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices), queue: queue, action: devicesChanged)]
        cameras += Self.cameras().map {
            CameraPropertyListener(object: $0, selector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere), queue: queue, action: changed)
        }
        audioListeners = audio.compactMap { $0 }
        cameraListeners = cameras.compactMap { $0 }
        refresh()
    }

    private func refresh() {
        guard !isStopped else { return }
        let microphone = Self.audioInputDevices().contains { Self.isRunning(audioDevice: $0) }
        let camera = Self.cameras().contains { Self.isRunning(camera: $0) }
        guard last?.microphone != microphone || last?.camera != camera else { return }
        last = (microphone, camera)
        report(microphone, camera)
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
