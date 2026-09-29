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
    private var listener: AudioPropertyListener?
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
        listener = AudioPropertyListener(
            object: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultOutputDevice,
            queue: .main
        ) { [weak self] in
            MainActor.assumeIsolated {
                self?.defaultOutputChanged()
            }
        }
        if listener == nil {
            Log.app.error("could not observe the default output device")
        }
    }

    func stop() {
        listener = nil
        batteryTask?.cancel()
        alerts.withdraw(.audioDevice)
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
