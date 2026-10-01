import CoreAudio
import CoreMediaIO
import Foundation
import Observation

/// Whether any app is using a microphone or a camera, like the dots on iPhone, and whether
/// a FaceTime or phone call is going on (the compact island then counts its time).
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
    /// When the current call started, as far as Halo saw it.
    private(set) var callStart: Date?
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
        let watcher = DeviceUsageWatcher { [weak self] usage in
            Task { @MainActor in
                self?.apply(usage, generation: generation)
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
        callStart = nil
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.privacyIndicatorEnabled = enabled
        if enabled { start() } else { stop() }
    }

    private func apply(_ usage: DeviceUsage, generation: Int) {
        guard watcher != nil, generation == self.generation else { return }
        if usage.microphone != isMicrophoneInUse { isMicrophoneInUse = usage.microphone }
        if usage.camera != isCameraInUse { isCameraInUse = usage.camera }
        if usage.call != (callStart != nil) { callStart = usage.call ? Date() : nil }
    }
}

private struct DeviceUsage: Sendable, Equatable {
    var microphone: Bool
    var camera: Bool
    var call: Bool
}

/// Watches the devices on a private serial queue. CoreAudio and above all CoreMediaIO
/// calls can block for seconds (Continuity Camera devices appearing after wake, a DAL
/// plug-in loading), so none of them runs on the main thread: a stalled main thread leaves
/// the lock screen card on screen after unlocking and times out the media key tap.
///
/// `@unchecked Sendable`: every mutable property is touched only on `queue`.
private final class DeviceUsageWatcher: @unchecked Sendable {
    private let queue = DispatchQueue(label: "io.github.sonofrangu.halo.privacy", qos: .utility)
    private let report: @Sendable (DeviceUsage) -> Void
    private var audioListeners: [AudioPropertyListener] = []
    private var cameraListeners: [CameraPropertyListener] = []
    /// Kept apart: the process list changes whenever any app starts playing, and that
    /// should not rescan the cameras.
    private var callListeners: [AudioPropertyListener] = []
    private var last: DeviceUsage?
    private var isStopped = false

    /// The system services that carry the audio of FaceTime calls and of iPhone calls
    /// relayed to the Mac; the FaceTime and Phone apps themselves never open the microphone.
    private static let callServices: Set<String> = ["com.apple.avconferenced", "com.apple.TelephonyUtilities"]

    init(report: @escaping @Sendable (DeviceUsage) -> Void) {
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
        callListeners.removeAll()
    }

    /// (Re)registers on the device lists and on every input device and camera, then on the
    /// calls.
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
        rewatchCalls()
    }

    /// (Re)registers on the audio process list and on the call services' audio input.
    private func rewatchCalls() {
        guard !isStopped else { return }
        callListeners.removeAll()
        let changed: @Sendable () -> Void = { [weak self] in self?.refresh() }
        let processesChanged: @Sendable () -> Void = { [weak self] in self?.rewatchCalls() }
        var calls = [AudioPropertyListener(object: AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyProcessObjectList, queue: queue, action: processesChanged)]
        calls += Self.callProcesses().map {
            AudioPropertyListener(object: $0, selector: kAudioProcessPropertyIsRunningInput, queue: queue, action: changed)
        }
        callListeners = calls.compactMap { $0 }
        refresh()
    }

    private func refresh() {
        guard !isStopped else { return }
        let usage = DeviceUsage(
            microphone: Self.audioInputDevices().contains { Self.isRunning(audioDevice: $0) },
            camera: Self.cameras().contains { Self.isRunning(camera: $0) },
            call: Self.callProcesses().contains { Self.isRunningInput(process: $0) }
        )
        guard usage != last else { return }
        last = usage
        report(usage)
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

    /// Audio clients of the call services (CoreAudio lists one per process playing or
    /// recording).
    private static func callProcesses() -> [AudioObjectID] {
        var address = audioAddress(kAudioHardwarePropertyProcessObjectList)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var processes = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &processes) == noErr else { return [] }
        return processes.filter { process in
            var bundle = audioAddress(kAudioProcessPropertyBundleID)
            var identifier: Unmanaged<CFString>?
            var bundleSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(process, &bundle, 0, nil, &bundleSize, &identifier) == noErr,
                  let identifier = identifier?.takeRetainedValue() as String?
            else { return false }
            return callServices.contains(identifier)
        }
    }

    private static func isRunningInput(process: AudioObjectID) -> Bool {
        var address = audioAddress(kAudioProcessPropertyIsRunningInput)
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(process, &address, 0, nil, &size, &running) == noErr && running != 0
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
