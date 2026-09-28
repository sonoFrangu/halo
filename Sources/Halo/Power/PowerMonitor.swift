import CoreFoundation
import IOKit.ps

/// Watches the internal battery through IOKit power source notifications (the system
/// calls back only when something changes) and posts charging and low-battery alerts.
@MainActor
final class PowerMonitor {
    private let alerts: AlertCenter
    private var source: CFRunLoopSource?
    private var last: PowerSnapshot?

    init(alerts: AlertCenter) {
        self.alerts = alerts
    }

    func start() {
        guard source == nil else { return }
        last = Self.read()
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource(powerSourcesCallback, context)?.takeRetainedValue() else {
            Log.app.error("could not register for power source notifications")
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        self.source = source
    }

    func stop() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        source = nil
        alerts.withdraw(.power)
    }

    fileprivate func powerSourcesChanged() {
        guard let snapshot = Self.read() else { return }
        defer { last = snapshot }
        if let alert = PowerTransition.alert(from: last, to: snapshot) {
            alerts.post(.power(alert))
        }
    }

    /// The internal battery's state, or `nil` on Macs without one.
    static func read() -> PowerSnapshot? {
        guard
            let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return nil
        }
        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else {
                continue
            }
            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = description[kIOPSMaxCapacityKey] as? Int ?? 100
            let timeToFull = description[kIOPSTimeToFullChargeKey] as? Int ?? -1
            return PowerSnapshot(
                percent: maximum > 0 ? current * 100 / maximum : 0,
                isPluggedIn: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                minutesToFull: timeToFull > 0 ? timeToFull : nil
            )
        }
        return nil
    }
}

/// Carries the monitor pointer into the main actor. `@unchecked Sendable`: the run loop
/// source is on the main run loop, so the callback runs on the main thread.
private struct PowerCallbackContext: @unchecked Sendable {
    let monitor: UnsafeMutableRawPointer
}

private func powerSourcesCallback(_ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let box = PowerCallbackContext(monitor: context)
    MainActor.assumeIsolated {
        Unmanaged<PowerMonitor>.fromOpaque(box.monitor).takeUnretainedValue().powerSourcesChanged()
    }
}
