import CoreAudio
import Foundation

/// Posts an alert when headphones become the output: AirPods connecting (macOS switches
/// output to them), or the user picking them. Event driven through a CoreAudio property
/// listener on the default output device. Batteries arrive a moment later from
/// `BluetoothBatteryReader`, updating the alert in place.
@MainActor
final class AudioDeviceMonitor {
    private let alerts: AlertCenter
    private let volume: SystemVolume
    private var listener: AudioObjectPropertyListenerBlock?
    private var currentDevice: AudioObjectID?
    private var batteryTask: Task<Void, Never>?

    /// Some headphones publish batteries a few seconds after connecting.
    static let batteryRetryDelay: Duration = .seconds(4)

    init(alerts: AlertCenter, volume: SystemVolume) {
        self.alerts = alerts
        self.volume = volume
    }

    func start() {
        guard listener == nil else { return }
        currentDevice = volume.defaultOutputDevice
        var address = Self.defaultOutputAddress
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.defaultOutputChanged()
            }
        }
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, block
        )
        if status == noErr {
            listener = block
        } else {
            Log.app.error("could not observe the default output device (\(status))")
        }
    }

    func stop() {
        if let listener {
            var address = Self.defaultOutputAddress
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, listener
            )
        }
        listener = nil
        batteryTask?.cancel()
        alerts.withdraw(.audioDevice)
    }

    private static var defaultOutputAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func defaultOutputChanged() {
        let device = volume.defaultOutputDevice
        guard device != currentDevice else { return }
        currentDevice = device

        let route = volume.route
        guard route != .speakers, let name = volume.outputName else { return }

        let alert = AudioDeviceAlert(name: name, route: route, batteries: .none, volume: volume.level())
        alerts.post(.audioDevice(alert))

        batteryTask?.cancel()
        batteryTask = Task { [weak self] in
            var batteries = await BluetoothBatteryReader.batteries(of: name)
            if batteries?.isEmpty ?? true {
                try? await Task.sleep(for: Self.batteryRetryDelay)
                guard !Task.isCancelled else { return }
                batteries = await BluetoothBatteryReader.batteries(of: name)
            }
            guard
                !Task.isCancelled,
                let self,
                let batteries,
                !batteries.isEmpty,
                self.currentDevice == device
            else {
                return
            }
            var updated = alert
            updated.batteries = batteries
            self.alerts.post(.audioDevice(updated))
        }
    }
}
