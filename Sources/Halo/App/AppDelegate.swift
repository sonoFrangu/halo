import AppKit

/// Composition root: creates the shared services, the islands, the floating cards and the
/// menu bar item.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var features: Features?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let alerts = AlertCenter()
        let volume = SystemVolume()
        let nowPlaying = NowPlayingController(model: NowPlayingModel())
        let hud = HUDController(alerts: alerts, volume: volume)
        let lyrics = LyricsController(player: nowPlaying.model)
        let weather = WeatherController()
        let shelf = ShelfController()
        let calendar = CalendarController(alerts: alerts)
        let screenshots = ScreenshotController(alerts: alerts, shelf: shelf.store)
        let timers = TimerController(alerts: alerts)
        let privacy = PrivacyIndicators()
        let energy = EnergyMode()
        let islands = IslandsCoordinator(
            services: IslandServices(
                nowPlaying: nowPlaying,
                hud: hud,
                alerts: alerts,
                lyrics: lyrics,
                weather: weather,
                shelf: shelf,
                calendar: calendar,
                screenshots: screenshots,
                timers: timers,
                privacy: privacy,
                energy: energy
            )
        )
        let cardActions = PlayerActions.card(for: nowPlaying)

        let features = Features(
            player: nowPlaying.model,
            nowPlaying: nowPlaying,
            hud: hud,
            power: PowerMonitor(alerts: alerts),
            audioDevices: AudioDeviceMonitor(alerts: alerts, volume: volume),
            lyrics: lyrics,
            weather: weather,
            shelf: shelf,
            calendar: calendar,
            screenshots: screenshots,
            timers: timers,
            privacy: privacy,
            keyboard: KeyboardMonitor(alerts: alerts),
            presentation: PresentationDetector(alerts: alerts),
            energy: energy,
            notifications: NotificationMirror(alerts: alerts),
            desktopWidget: DesktopWidgetController(
                player: nowPlaying.model,
                lyrics: lyrics.model,
                weather: weather.model,
                actions: cardActions
            ),
            lockScreen: LockScreenController(player: nowPlaying.model, lyrics: lyrics.model, actions: cardActions),
            islands: islands,
            loginItem: LoginItemController()
        )
        self.features = features
        statusItem = StatusItemController(features: features)

        nowPlaying.start()
        hud.start()
        weather.start()
        shelf.start()
        calendar.start()
        screenshots.start()
        privacy.start()
        features.notifications.start()
        features.keyboard.start()
        features.presentation.start()
        features.desktopWidget.start()
        features.lockScreen.start()
        if Preferences.lyricsEnabled { lyrics.start() }
        if Preferences.chargingAlertsEnabled { features.power.start() }
        if Preferences.headphoneAlertsEnabled { features.audioDevices.start() }
        Log.app.info("Halo started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard let features else { return }
        features.nowPlaying.stop()
        features.hud.stop()
        features.power.stop()
        features.audioDevices.stop()
        features.lyrics.stop()
        features.notifications.stop()
        features.lockScreen.stop()
        features.calendar.stop()
        features.screenshots.stop()
        features.privacy.stop()
        features.keyboard.stop()
        features.presentation.stop()
    }
}

/// Everything the menu can show or toggle.
@MainActor
struct Features {
    let player: NowPlayingModel
    let nowPlaying: NowPlayingController
    let hud: HUDController
    let power: PowerMonitor
    let audioDevices: AudioDeviceMonitor
    let lyrics: LyricsController
    let weather: WeatherController
    let shelf: ShelfController
    let calendar: CalendarController
    let screenshots: ScreenshotController
    let timers: TimerController
    let privacy: PrivacyIndicators
    let keyboard: KeyboardMonitor
    let presentation: PresentationDetector
    let energy: EnergyMode
    let notifications: NotificationMirror
    let desktopWidget: DesktopWidgetController
    let lockScreen: LockScreenController
    let islands: IslandsCoordinator
    let loginItem: LoginItemController
}
