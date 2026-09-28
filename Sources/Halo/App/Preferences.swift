import Foundation

/// Persisted user choices.
@MainActor
enum Preferences {
    private enum Key {
        static let hudReplacement = "hudReplacementEnabled"
        static let askedForAccessibility = "askedForAccessibility"
        static let allDisplays = "showsOnAllDisplays"
        static let chargingAlerts = "chargingAlertsEnabled"
        static let headphoneAlerts = "headphoneAlertsEnabled"
        static let lyrics = "showsLyrics"
        static let lyricsFeature = "lyricsEnabled"
        static let lyricsLead = "lyricsLead"
        static let weather = "weatherEnabled"
        static let shelf = "shelfEnabled"
        static let notifications = "notificationsEnabled"
        static let desktopWidget = "desktopWidgetEnabled"
        static let lockScreen = "lockScreenEnabled"
        static let gestures = "gesturesEnabled"
        static let haptics = "hapticsEnabled"
        static let hoverDelay = "hoverDelay"
        static let calendar = "calendarEnabled"
        static let screenshots = "screenshotsEnabled"
        static let timer = "timerEnabled"
        static let privacyIndicator = "privacyIndicatorEnabled"
        static let keyboardAlerts = "keyboardAlertsEnabled"
        static let presentationMode = "presentationModeEnabled"
        static let lowPowerAdaptive = "lowPowerAdaptive"
        static let focus = "focusEnabled"
        static let notificationsFollowFocus = "notificationsFollowFocus"
        static let transfers = "transfersEnabled"
        static let unlockAnimation = "unlockAnimationEnabled"
        static let systemTimers = "systemTimersEnabled"
        static let siri = "siriEnabled"
    }

    private static func flag(_ key: String, default value: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? value
    }

    private static var defaults: UserDefaults { .standard }

    /// Replace the system brightness and volume HUD with the island. On by default.
    static var hudReplacementEnabled: Bool {
        get { defaults.object(forKey: Key.hudReplacement) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.hudReplacement) }
    }

    /// An island on every display (externals and Macs without a notch), not only the
    /// notched or primary one.
    static var showsOnAllDisplays: Bool {
        get { flag(Key.allDisplays, default: true) }
        set { defaults.set(newValue, forKey: Key.allDisplays) }
    }

    static var chargingAlertsEnabled: Bool {
        get { flag(Key.chargingAlerts, default: true) }
        set { defaults.set(newValue, forKey: Key.chargingAlerts) }
    }

    static var headphoneAlertsEnabled: Bool {
        get { flag(Key.headphoneAlerts, default: true) }
        set { defaults.set(newValue, forKey: Key.headphoneAlerts) }
    }

    /// Fetch synced lyrics at all (menu).
    static var lyricsEnabled: Bool {
        get { flag(Key.lyricsFeature, default: true) }
        set { defaults.set(newValue, forKey: Key.lyricsFeature) }
    }

    /// The lyrics panel is open under the player (toggled from the player).
    static var showsLyrics: Bool {
        get { flag(Key.lyrics, default: true) }
        set { defaults.set(newValue, forKey: Key.lyrics) }
    }

    static var weatherEnabled: Bool {
        get { flag(Key.weather, default: true) }
        set { defaults.set(newValue, forKey: Key.weather) }
    }

    /// The file shelf tab, which also opens the island when files are dragged to it.
    static var shelfEnabled: Bool {
        get { flag(Key.shelf, default: true) }
        set { defaults.set(newValue, forKey: Key.shelf) }
    }

    /// Mirror system notifications in the island (needs Full Disk Access).
    static var notificationsEnabled: Bool {
        get { flag(Key.notifications, default: true) }
        set { defaults.set(newValue, forKey: Key.notifications) }
    }

    /// The glass Now Playing / clock widget on the desktop. Off by default.
    static var desktopWidgetEnabled: Bool {
        get { flag(Key.desktopWidget, default: false) }
        set { defaults.set(newValue, forKey: Key.desktopWidget) }
    }

    /// Music and lyrics on the lock screen.
    static var lockScreenEnabled: Bool {
        get { flag(Key.lockScreen, default: true) }
        set { defaults.set(newValue, forKey: Key.lockScreen) }
    }

    /// Upcoming events in the island and meeting reminders.
    static var calendarEnabled: Bool {
        get { flag(Key.calendar, default: true) }
        set { defaults.set(newValue, forKey: Key.calendar) }
    }

    /// New screenshots appear in the island.
    static var screenshotsEnabled: Bool {
        get { flag(Key.screenshots, default: true) }
        set { defaults.set(newValue, forKey: Key.screenshots) }
    }

    /// Timer and Pomodoro tab, and the timer's live activity in the wings.
    static var timerEnabled: Bool {
        get { flag(Key.timer, default: true) }
        set { defaults.set(newValue, forKey: Key.timer) }
    }

    /// The orange/green dot while an app uses the microphone or a camera.
    static var privacyIndicatorEnabled: Bool {
        get { flag(Key.privacyIndicator, default: true) }
        set { defaults.set(newValue, forKey: Key.privacyIndicator) }
    }

    /// Brief alerts for keyboard layout changes and Caps Lock.
    static var keyboardAlertsEnabled: Bool {
        get { flag(Key.keyboardAlerts, default: true) }
        set { defaults.set(newValue, forKey: Key.keyboardAlerts) }
    }

    /// Quiet alerts while a full-screen app is in front.
    static var presentationModeEnabled: Bool {
        get { flag(Key.presentationMode, default: true) }
        set { defaults.set(newValue, forKey: Key.presentationMode) }
    }

    /// Trim animations and redraws in Low Power Mode.
    static var lowPowerAdaptive: Bool {
        get { flag(Key.lowPowerAdaptive, default: true) }
        set { defaults.set(newValue, forKey: Key.lowPowerAdaptive) }
    }

    /// Announce Focus changes in the island.
    static var focusEnabled: Bool {
        get { flag(Key.focus, default: true) }
        set { defaults.set(newValue, forKey: Key.focus) }
    }

    /// Keep mirrored notifications quiet while a Focus is on.
    static var notificationsFollowFocus: Bool {
        get { flag(Key.notificationsFollowFocus, default: true) }
        set { defaults.set(newValue, forKey: Key.notificationsFollowFocus) }
    }

    /// Downloads and AirDrops as a live activity.
    static var transfersEnabled: Bool {
        get { flag(Key.transfers, default: true) }
        set { defaults.set(newValue, forKey: Key.transfers) }
    }

    /// The padlock opening in the island when the Mac is unlocked.
    static var unlockAnimationEnabled: Bool {
        get { flag(Key.unlockAnimation, default: true) }
        set { defaults.set(newValue, forKey: Key.unlockAnimation) }
    }

    /// Timers started with Siri or the Clock app, as a live activity.
    static var systemTimersEnabled: Bool {
        get { flag(Key.systemTimers, default: true) }
        set { defaults.set(newValue, forKey: Key.systemTimers) }
    }

    /// The island glows while Siri is on screen.
    static var siriEnabled: Bool {
        get { flag(Key.siri, default: true) }
        set { defaults.set(newValue, forKey: Key.siri) }
    }

    /// Swipes over the island skip tracks and change the volume.
    static var gesturesEnabled: Bool {
        get { flag(Key.gestures, default: true) }
        set { defaults.set(newValue, forKey: Key.gestures) }
    }

    /// Force Touch trackpad feedback for gestures.
    static var hapticsEnabled: Bool {
        get { flag(Key.haptics, default: true) }
        set { defaults.set(newValue, forKey: Key.haptics) }
    }

    /// Seconds synced lyrics are shown ahead of their timestamps (negative: later).
    static var lyricsLead: Double {
        get { (defaults.object(forKey: Key.lyricsLead) as? Double).map { min(max($0, -1), 2) } ?? 0.25 }
        set { defaults.set(newValue, forKey: Key.lyricsLead) }
    }

    /// Seconds the pointer rests on the notch before the island opens.
    static var hoverDelay: Double {
        get { (defaults.object(forKey: Key.hoverDelay) as? Double).map { min(max($0, 0), 0.6) } ?? 0.09 }
        set { defaults.set(newValue, forKey: Key.hoverDelay) }
    }

    /// The Accessibility prompt is shown automatically only once; afterwards it is reachable
    /// from the menu.
    static var hasAskedForAccessibility: Bool {
        get { defaults.bool(forKey: Key.askedForAccessibility) }
        set { defaults.set(newValue, forKey: Key.askedForAccessibility) }
    }
}
