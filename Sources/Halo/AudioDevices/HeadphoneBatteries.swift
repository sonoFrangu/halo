import Foundation

/// Battery levels (0...100) reported by Bluetooth headphones. AirPods report left, right
/// and case; single-battery headphones (AirPods Max, many Beats) report `main`.
struct HeadphoneBatteries: Sendable, Equatable {
    var left: Int?
    var right: Int?
    var `case`: Int?
    var main: Int?

    var isEmpty: Bool {
        left == nil && right == nil && `case` == nil && main == nil
    }

    static let none = HeadphoneBatteries()

    /// Reads a device's batteries out of `system_profiler SPBluetoothDataType -json`.
    ///
    /// The output lists connected devices as one-key dictionaries (`{"Name": {…}}`) whose
    /// battery entries look like `"device_batteryLevelLeft": "90%"`. Matching is by the
    /// name CoreAudio reports for the output device, falling back to a case-insensitive
    /// comparison.
    static func parse(systemProfilerJSON data: Data, deviceName: String) -> HeadphoneBatteries? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let controllers = root["SPBluetoothDataType"] as? [[String: Any]]
        else {
            return nil
        }
        for controller in controllers {
            guard let connected = controller["device_connected"] as? [[String: Any]] else { continue }
            for entry in connected {
                for (name, value) in entry {
                    guard
                        name == deviceName || name.caseInsensitiveCompare(deviceName) == .orderedSame,
                        let properties = value as? [String: Any]
                    else {
                        continue
                    }
                    return batteries(in: properties)
                }
            }
        }
        return nil
    }

    private static func batteries(in properties: [String: Any]) -> HeadphoneBatteries {
        func level(_ key: String) -> Int? {
            guard let text = properties[key] as? String else { return nil }
            let digits = text.filter(\.isNumber)
            guard let value = Int(digits), (0...100).contains(value) else { return nil }
            return value
        }
        return HeadphoneBatteries(
            left: level("device_batteryLevelLeft"),
            right: level("device_batteryLevelRight"),
            case: level("device_batteryLevelCase"),
            main: level("device_batteryLevelMain") ?? level("device_batteryLevel")
        )
    }
}
