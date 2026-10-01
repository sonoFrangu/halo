import Foundation
import Testing
@testable import Halo

@MainActor
struct AlertCenterTests {
    private func notification(_ id: Int64, from app: String = "com.example", count: Int = 1) -> IslandAlert {
        .notification(NotificationAlert(id: id, bundleIdentifier: app, text: NotificationText(headline: "T\(id)"), count: count))
    }

    private let charging = IslandAlert.power(PowerAlert(event: .connected, level: 0.5, isCharging: true, minutesToFull: 60))

    @Test func firstAlertShowsImmediately() {
        let center = AlertCenter()
        center.post(charging)
        #expect(center.current == charging)
    }

    @Test func sameKindReplacesInPlace() {
        let center = AlertCenter()
        center.post(notification(1))
        center.post(notification(2, from: "com.other"))
        #expect(center.current == notification(2, from: "com.other"))
        center.dismissCurrent()
        #expect(center.current == nil)
    }

    @Test func notificationsFromTheSameAppStack() {
        let center = AlertCenter()
        center.post(notification(1))
        center.post(notification(2))
        center.post(notification(3))
        #expect(center.current == notification(3, count: 3))
        center.post(notification(4, from: "com.other"))
        #expect(center.current == notification(4, from: "com.other"))
    }

    @Test func queuedNotificationsStackToo() {
        let center = AlertCenter()
        center.post(charging)
        center.post(notification(1))
        center.post(notification(2))
        center.dismissCurrent()
        #expect(center.current == notification(2, count: 2))
    }

    @Test func otherKindsQueueInOrder() {
        let center = AlertCenter()
        center.post(charging)
        center.post(notification(1))
        #expect(center.current == charging)
        center.dismissCurrent()
        #expect(center.current == notification(1))
        center.dismissCurrent()
        #expect(center.current == nil)
    }

    @Test func hudPreemptsAndTheInterruptedAlertResumes() {
        let center = AlertCenter()
        center.post(notification(1))
        center.post(.hud)
        #expect(center.current == .hud)
        center.dismissCurrent()
        #expect(center.current == notification(1))
    }

    @Test func quietModeDropsInterruptionsButKeepsFeedback() {
        let center = AlertCenter()
        center.isQuiet = true
        center.post(notification(1))
        center.post(charging)
        #expect(center.current == nil)

        let low = IslandAlert.power(PowerAlert(event: .low, level: 0.1, isCharging: false, minutesToFull: nil))
        center.post(low)
        #expect(center.current == low)
        center.post(.hud)
        #expect(center.current == .hud)
    }

    @Test func withdrawRemovesVisibleAndQueuedAlerts() {
        let center = AlertCenter()
        center.post(charging)
        center.post(notification(1))
        center.withdraw(.power)
        #expect(center.current == notification(1))
        center.withdraw(.notification)
        #expect(center.current == nil)
    }
}

struct PowerTransitionTests {
    private func snapshot(_ percent: Int, pluggedIn: Bool, charging: Bool = false) -> PowerSnapshot {
        PowerSnapshot(percent: percent, isPluggedIn: pluggedIn, isCharging: charging, minutesToFull: nil)
    }

    @Test func noAlertAtLaunch() {
        #expect(PowerTransition.alert(from: nil, to: snapshot(50, pluggedIn: true)) == nil)
    }

    @Test func pluggingInAndOut() {
        let connected = PowerTransition.alert(from: snapshot(40, pluggedIn: false), to: snapshot(40, pluggedIn: true, charging: true))
        #expect(connected?.event == .connected)
        #expect(connected?.isCharging == true)

        let disconnected = PowerTransition.alert(from: snapshot(90, pluggedIn: true), to: snapshot(90, pluggedIn: false))
        #expect(disconnected?.event == .disconnected)
    }

    @Test func lowBatteryWarnsOncePerThreshold() {
        #expect(PowerTransition.alert(from: snapshot(21, pluggedIn: false), to: snapshot(20, pluggedIn: false))?.event == .low)
        #expect(PowerTransition.alert(from: snapshot(20, pluggedIn: false), to: snapshot(19, pluggedIn: false)) == nil)
        #expect(PowerTransition.alert(from: snapshot(11, pluggedIn: false), to: snapshot(10, pluggedIn: false))?.event == .low)
        #expect(PowerTransition.alert(from: snapshot(21, pluggedIn: true), to: snapshot(20, pluggedIn: true)) == nil)
    }
}

struct HeadphoneBatteriesTests {
    private let json = """
    {
      "SPBluetoothDataType": [
        {
          "controller_properties": { "controller_state": "attrib_on" },
          "device_connected": [
            { "Magic Mouse": { "device_batteryLevelMain": "64%" } },
            {
              "AirPods Pro di Matteo": {
                "device_batteryLevelCase": "55%",
                "device_batteryLevelLeft": "100%",
                "device_batteryLevelRight": "90%",
                "device_minorType": "Headphones"
              }
            }
          ],
          "device_not_connected": [
            { "Old Headphones": { "device_batteryLevelMain": "10%" } }
          ]
        }
      ]
    }
    """

    @Test func readsEarbudsAndCase() {
        let batteries = HeadphoneBatteries.parse(systemProfilerJSON: Data(json.utf8), deviceName: "AirPods Pro di Matteo")
        #expect(batteries == HeadphoneBatteries(left: 100, right: 90, case: 55, main: nil))
    }

    @Test func readsSingleBatteryDevices() {
        let batteries = HeadphoneBatteries.parse(systemProfilerJSON: Data(json.utf8), deviceName: "magic mouse")
        #expect(batteries?.main == 64)
    }

    @Test func ignoresDisconnectedAndUnknownDevices() {
        #expect(HeadphoneBatteries.parse(systemProfilerJSON: Data(json.utf8), deviceName: "Old Headphones") == nil)
        #expect(HeadphoneBatteries.parse(systemProfilerJSON: Data(json.utf8), deviceName: "Nope") == nil)
        #expect(HeadphoneBatteries.parse(systemProfilerJSON: Data("garbage".utf8), deviceName: "Nope") == nil)
    }

    @Test func warnsOnceWhenAWornBatteryDropsToAWarningLevel() {
        let full = HeadphoneBatteries(left: 60, right: 58, case: 90)
        #expect(HeadphoneBatteries(left: 40, right: 20, case: 90).crossedWarningLevel(since: full))
        #expect(HeadphoneBatteries(left: 30, right: 9, case: 90).crossedWarningLevel(since: HeadphoneBatteries(left: 30, right: 15)))
        // Already below: no second warning until the next level.
        #expect(!HeadphoneBatteries(left: 30, right: 18).crossedWarningLevel(since: HeadphoneBatteries(left: 30, right: 19)))
        // The case never counts, and charging back up is not a warning.
        #expect(!HeadphoneBatteries(left: 60, right: 60, case: 5).crossedWarningLevel(since: full))
        #expect(!full.crossedWarningLevel(since: HeadphoneBatteries(left: 15, right: 15)))
        #expect(HeadphoneBatteries(main: 10).crossedWarningLevel(since: HeadphoneBatteries(main: 11)))
    }
}

struct BluetoothProductTests {
    @Test func readsProductIDsOfConnectedAndPairedDevices() {
        let json = """
        {
          "SPBluetoothDataType": [
            {
              "device_connected": [
                { "AirPods di Matteo": { "device_productID": "0x201B", "device_batteryLevelLeft": "90%" } },
                { "Tastiera": { "device_minorType": "Keyboard" } }
              ],
              "device_not_connected": [
                { "Beats Studio Buds": { "device_productID": "0x2011" } }
              ]
            }
          ]
        }
        """
        #expect(BluetoothProduct.ids(systemProfilerJSON: Data(json.utf8)) == [
            "AirPods di Matteo": "0x201B",
            "Beats Studio Buds": "0x2011",
        ])
        #expect(BluetoothProduct.ids(systemProfilerJSON: Data("garbage".utf8)).isEmpty)
    }
}

struct OutputRouteTests {
    @Test func classifiesAirPodsByProductWhateverTheirName() {
        func route(_ id: String?, _ product: String?, name: String = "Cuffie di Matteo") -> SystemVolume.Route {
            SystemVolume.route(deviceName: name, productID: id, productName: product, isBluetooth: true)
        }
        #expect(route("0x200F", "AirPods") == .airPods)
        #expect(route("0x2013", "AirPods") == .airPods3)
        #expect(route("0x201B", "AirPods") == .airPods4)
        #expect(route("0x2027", "AirPods Pro") == .airPodsPro)
        #expect(route("0x201F", "AirPods Max") == .airPodsMax)
        #expect(route("0x2011", "Beats Studio Buds") == .headphones)
        #expect(route(nil, nil, name: "AirPods Pro di Matteo") == .airPodsPro)
        #expect(route(nil, nil, name: "AirPods di Matteo") == .airPods)
        #expect(SystemVolume.route(deviceName: "MacBook Air Speakers", productID: nil, productName: nil, isBluetooth: false) == .speakers)
    }
}
