/// Battery state of the Mac at one moment.
struct PowerSnapshot: Sendable, Equatable {
    /// 0...100.
    var percent: Int
    var isPluggedIn: Bool
    var isCharging: Bool
    var minutesToFull: Int?

    var level: Double {
        Double(min(max(percent, 0), 100)) / 100
    }
}

/// Which alert, if any, a change of battery state deserves.
enum PowerTransition {
    /// Battery levels that trigger a warning when crossed downwards on battery power.
    static let lowThresholds = [20, 10, 5]

    static func alert(from old: PowerSnapshot?, to new: PowerSnapshot) -> PowerAlert? {
        // No alert for the state found at launch.
        guard let old else { return nil }

        if !old.isPluggedIn && new.isPluggedIn {
            return PowerAlert(event: .connected, level: new.level, isCharging: new.isCharging, minutesToFull: new.minutesToFull)
        }
        if old.isPluggedIn && !new.isPluggedIn {
            return PowerAlert(event: .disconnected, level: new.level, isCharging: false, minutesToFull: nil)
        }
        if !new.isPluggedIn, lowThresholds.contains(where: { old.percent > $0 && new.percent <= $0 }) {
            return PowerAlert(event: .low, level: new.level, isCharging: false, minutesToFull: nil)
        }
        return nil
    }
}
