import CoreAudio
import Foundation

/// Posts an alert when headphones become the output: AirPods connecting (macOS switches
/// output to them), or the user picking them. Event driven through a CoreAudio property
/// listener on the default output device. Batteries arrive a moment later from
/// `BluetoothBatteryReader`, updating the alert in place; while the headphones stay the
/// output they are read again every few minutes, and the alert returns when one runs low.
/// The model's picture and symbols come from product IDs read at launch (`BluetoothProduct`),
/// so the alert shows them right away; a device paired since then gets them a moment later.
@MainActor
final class AudioDeviceMonitor {
    private let alerts: AlertCenter
    private let volume: SystemVolume
    private var listener: AudioPropertyListener?
    private var currentDevice: AudioObjectID?
    private var batteryTask: Task<Void, Never>?

    /// Some headphones publish batteries a few seconds after connecting.
    static let batteryRetryDelay: Duration = .seconds(4)
    /// A read costs about 30 ms of CPU, so checking this often while listening is cheap.
    static let batteryPollInterval: Duration = .seconds(300)

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
        batteryTask?.cancel()

        let route = volume.route
        guard route != .speakers, let name = volume.outputName else { return }

        let alert = AudioDeviceAlert(
            name: name,
            route: route,
            productID: BluetoothProduct.id(ofDevice: name),
            batteries: .none
        )
        alerts.post(.audioDevice(alert))

        batteryTask = Task { [weak self] in
            var alert = alert
            if alert.productID == nil {
                await BluetoothProduct.refreshIDs()
                guard !Task.isCancelled, let self else { return }
                if let id = BluetoothProduct.id(ofDevice: name), self.currentDevice == device {
                    alert.productID = id
                    alert.route = self.volume.route
                    self.alerts.post(.audioDevice(alert))
                }
            }
            var batteries = await BluetoothBatteryReader.batteries(of: name)
            if batteries?.isEmpty ?? true {
                try? await Task.sleep(for: Self.batteryRetryDelay)
                guard !Task.isCancelled else { return }
                batteries = await BluetoothBatteryReader.batteries(of: name)
            }
            guard var last = batteries, !last.isEmpty else { return }
            self?.showBatteries(last, of: alert, on: device)

            // Cancelled when the output changes (see above) or the monitor stops.
            while true {
                try? await Task.sleep(for: Self.batteryPollInterval, tolerance: .seconds(60))
                guard !Task.isCancelled, self != nil else { return }
                guard let now = await BluetoothBatteryReader.batteries(of: name), !now.isEmpty else { continue }
                if now.crossedWarningLevel(since: last) {
                    self?.showBatteries(now, of: alert, on: device)
                }
                last = now
            }
        }
    }

    /// Shows the headphones' card again with `batteries`, if they are still the output.
    private func showBatteries(_ batteries: HeadphoneBatteries, of alert: AudioDeviceAlert, on device: AudioObjectID?) {
        guard !Task.isCancelled, currentDevice == device else { return }
        var updated = alert
        updated.batteries = batteries
        alerts.post(.audioDevice(updated))
    }
}
