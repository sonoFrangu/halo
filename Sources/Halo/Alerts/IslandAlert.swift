import Foundation

/// How an alert takes over the island.
enum AlertStyle: Sendable, Equatable {
    /// Beside the notch, at its height (HUD, charging).
    case wings
    /// Below the notch (headphones, notifications).
    case banner
    /// A square panel below the notch holding one big glyph (the Face ID unlock).
    case glyph
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
    /// The Mac was just unlocked, played in the chosen style.
    case unlock(UnlockAnimationStyle)
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
        case .hud, .power, .keyboard, .focus, .unlock(.padlock), .siri: .wings
        case .unlock(.faceID): .glyph
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

    /// `self` arriving while `previous`, of the same kind, is still up or queued: a
    /// notification from the same app stacks onto it and counts both, as Notification
    /// Center groups them; the same notification again (its photo arriving) keeps the
    /// count. Anything else simply replaces it.
    func replacing(_ previous: IslandAlert) -> IslandAlert {
        guard
            case .notification(var next) = self,
            case .notification(let shown) = previous,
            next.bundleIdentifier == shown.bundleIdentifier
        else { return self }
        next.count = next.isSame(as: shown) ? shown.count : shown.count + next.count
        return .notification(next)
    }

    /// `self` with `other`, a notification of the same app it stands for too, counted in;
    /// what it shows stays.
    func counting(_ other: IslandAlert) -> IslandAlert? {
        guard
            case .notification(var alert) = self,
            case .notification(let added) = other,
            alert.bundleIdentifier == added.bundleIdentifier
        else { return nil }
        alert.count += added.count
        return .notification(alert)
    }

    /// Both are the same notification, from either source.
    func isSame(as other: IslandAlert) -> Bool {
        guard case .notification(let alert) = self, case .notification(let otherAlert) = other else { return false }
        return alert.isSame(as: otherAlert)
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
        // Glance's hold after a successful scan: the Face ID checkmark lands at 1.2 s.
        case .unlock: .milliseconds(1700)
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
    /// Bluetooth product ID (`"0x201B"`), when the device reports one: picks the model's
    /// picture and symbols.
    var productID: String?
    /// Battery levels in 0...100, when the device reports them.
    var batteries: HeadphoneBatteries
}

/// A system notification mirrored from Notification Center.
struct NotificationAlert: Sendable, Equatable {
    /// The database record's id; negative for a notification read off its banner, which has
    /// no record yet.
    var id: Int64
    var bundleIdentifier: String
    var text: NotificationText
    /// Photo attached to the notification; its thumbnail is loaded before the banner is posted.
    var imageURL: URL?
    /// Notifications from this app the banner stands for, this one included.
    var count = 1

    /// The same notification, whether read off its banner or from its database record.
    func isSame(as other: NotificationAlert) -> Bool {
        bundleIdentifier == other.bundleIdentifier && text == other.text
    }
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
