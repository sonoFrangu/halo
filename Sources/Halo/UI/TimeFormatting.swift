import Foundation

enum TimeFormatting {
    /// `m:ss`, or `h:mm:ss` from one hour on. Invalid input renders as `--:--`.
    static func string(_ interval: TimeInterval) -> String {
        guard interval.isFinite, interval >= 0 else { return "--:--" }
        let total = Int(interval.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
