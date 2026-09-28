import Foundation

/// How an alert takes over the island.
enum AlertStyle: Sendable, Equatable {
    /// Beside the notch, at its height (HUD, charging).
    case wings
    /// Below the notch (headphones, notifications).
    case banner
}

/// Something that briefly takes over the island.
enum IslandAlert: Sendable, Equatable {
    /// Brightness or volume changed; the content lives in `HUDModel`.
    case hud
    case power(PowerAlert)
    case audioDevice(AudioDeviceAlert)
    case notification(NotificationAlert)
    case calendar(CalendarAlert)
    case screenshot(ScreenshotAlert)
    case timer(TimerAlert)

    enum Kind: Sendable, Hashable {
        case hud
        case power
        case audioDevice
        case notification
        case calendar
        case screenshot
        case timer
    }

    var kind: Kind {
        switch self {
        case .hud: .hud
        case .power: .power
        case .audioDevice: .audioDevice
        case .notification: .notification
        case .calendar: .calendar
        case .screenshot: .screenshot
        case .timer: .timer
        }
    }

    var style: AlertStyle {
        switch self {
        case .hud, .power: .wings
        case .audioDevice, .notification, .calendar, .screenshot, .timer: .banner
        }
    }

    /// How long the alert stays once nothing holds it.
    var duration: Duration {
        switch self {
        case .hud: .milliseconds(1600)
        case .power: .milliseconds(3200)
        case .audioDevice: .milliseconds(4500)
        case .notification: .milliseconds(5500)
        case .calendar: .seconds(12)
        case .screenshot: .seconds(6)
        case .timer: .seconds(8)
        }
    }
}

/// Charger plugged in or out, or battery running low.
struct PowerAlert: Sendable, Equatable {
    enum Event: Sendable, Equatable {
        case connected
        case disconnected
        case low
    }

    var event: Event
    /// 0...1.
    var level: Double
    var isCharging: Bool
    /// Minutes until full, when the system knows.
    var minutesToFull: Int?
}

/// Headphones (AirPods and friends) just connected.
struct AudioDeviceAlert: Sendable, Equatable {
    var name: String
    var route: SystemVolume.Route
    /// Battery levels in 0...100, when the device reports them.
    var batteries: HeadphoneBatteries
    /// Output volume in 0...1, if the device has a volume control.
    var volume: Double?
}

/// A system notification mirrored from Notification Center.
struct NotificationAlert: Sendable, Equatable {
    var id: Int64
    var bundleIdentifier: String
    var appName: String
    var title: String
    var body: String?
}

/// A meeting is about to start.
struct CalendarAlert: Sendable, Equatable {
    var event: CalendarEvent
}

/// A screenshot or screen recording was just saved.
struct ScreenshotAlert: Sendable, Equatable {
    var url: URL
}
