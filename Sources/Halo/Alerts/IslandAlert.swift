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
    case keyboard(KeyboardAlert)
    case focus(FocusAlert)
    case transfer(TransferAlert)
    /// The Mac was just unlocked.
    case unlock
    /// Siri is on screen; held up by `SiriMonitor` until it closes.
    case siri

    enum Kind: Sendable, Hashable {
        case hud
        case power
        case audioDevice
        case notification
        case calendar
        case screenshot
        case timer
        case keyboard
        case focus
        case transfer
        case unlock
        case siri
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
        case .keyboard: .keyboard
        case .focus: .focus
        case .transfer: .transfer
        case .unlock: .unlock
        case .siri: .siri
        }
    }

    var style: AlertStyle {
        switch self {
        case .hud, .power, .keyboard, .focus, .unlock, .siri: .wings
        case .audioDevice, .notification, .calendar, .screenshot, .timer, .transfer: .banner
        }
    }

    /// Dropped in presentation mode: interruptions nobody asked for right now.
    var waitsOutPresentations: Bool {
        switch self {
        case .notification, .audioDevice, .screenshot, .transfer: true
        case .power(let power): power.event != .low
        case .hud, .calendar, .timer, .keyboard, .focus, .unlock, .siri: false
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
        case .keyboard: .milliseconds(1400)
        case .focus: .milliseconds(2200)
        case .transfer: .seconds(5)
        case .unlock: .milliseconds(1300)
        // Counts only once `SiriMonitor` lets go, and it withdraws the alert right away.
        case .siri: .seconds(1)
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

/// The keyboard layout changed or Caps Lock toggled.
enum KeyboardAlert: Sendable, Equatable {
    case layout(InputSource)
    case capsLock(on: Bool)
}

/// A Focus was turned on or off.
struct FocusAlert: Sendable, Equatable {
    var mode: FocusMode
    var isOn: Bool
}

/// A download or AirDrop finished.
struct TransferAlert: Sendable, Equatable {
    var name: String
    var kind: Transfer.Kind
    /// Where the file should now be (the folder the transfer was published in).
    var url: URL
}
