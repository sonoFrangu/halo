import AudioToolbox
import CoreAudio
import Foundation

/// Output volume and mute of the default output device through CoreAudio.
@MainActor
final class SystemVolume {
    /// How the current output device should be drawn in the HUD.
    enum Route: Equatable, Sendable {
        case speakers
        case headphones
        case airPods
        case airPodsPro
        case airPodsMax
    }

    var defaultOutputDevice: AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        guard status == noErr, device != AudioObjectID(kAudioObjectUnknown) else { return nil }
        return device
    }

    /// Volume in 0...1 of the default output, or `nil` if the device has no volume control.
    func level() -> Double? {
        guard let device = defaultOutputDevice else { return nil }
        var address = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return Double(value)
    }

    @discardableResult
    func setLevel(_ level: Double) -> Bool {
        guard let device = defaultOutputDevice else { return false }
        var address = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        guard isSettable(device, &address) else { return false }
        var value = Float32(min(max(level, 0), 1))
        let size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectSetPropertyData(device, &address, 0, nil, size, &value) == noErr
    }

    func isMuted() -> Bool {
        guard let device = defaultOutputDevice else { return false }
        var address = Self.address(kAudioDevicePropertyMute)
        guard AudioObjectHasProperty(device, &address) else { return false }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return false }
        return value != 0
    }

    @discardableResult
    func setMuted(_ muted: Bool) -> Bool {
        guard let device = defaultOutputDevice else { return false }
        var address = Self.address(kAudioDevicePropertyMute)
        guard isSettable(device, &address) else { return false }
        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(device, &address, 0, nil, size, &value) == noErr
    }

    var route: Route {
        guard let device = defaultOutputDevice else { return .speakers }
        let name = deviceName(device)?.lowercased() ?? ""
        if name.contains("airpods max") { return .airPodsMax }
        if name.contains("airpods pro") { return .airPodsPro }
        if name.contains("airpods") { return .airPods }
        return transportType(device) == kAudioDeviceTransportTypeBluetooth ? .headphones : .speakers
    }

    // MARK: Helpers

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func isSettable(_ device: AudioObjectID, _ address: inout AudioObjectPropertyAddress) -> Bool {
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
    }

    private func deviceName(_ device: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &name) { pointer in
            AudioObjectGetPropertyData(device, &address, 0, nil, &size, pointer)
        }
        guard status == noErr, let name else { return nil }
        return name.takeRetainedValue() as String
    }

    private func transportType(_ device: AudioObjectID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return 0 }
        return value
    }
}
