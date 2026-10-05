import AppKit

/// Composition root: creates the shared services, the islands, the floating cards and the
/// menu bar item.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var features: Features?
    private var statusItem: StatusItemController?
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        quitOnSignals()
        let alerts = AlertCenter()
        let volume = SystemVolume()
        let nowPlaying = NowPlayingController(model: NowPlayingModel())
        let hud = HUDController(alerts: alerts, volume: volume)
        let lyrics = LyricsController(player: nowPlaying.model)
        let weather = WeatherController()
        let shelf = ShelfController()
        let clipboard = ClipboardHistory()
        let calendar = CalendarController(alerts: alerts)
        let screenshots = ScreenshotController(alerts: alerts, shelf: shelf.store)
        let timers = TimerController(alerts: alerts)
        let systemTimers = SystemTimerMonitor(alerts: alerts)
        let transfers = TransferMonitor(alerts: alerts, shelf: shelf.store)
        let privacy = PrivacyIndicators()
        let energy = EnergyMode()
        let focus = FocusMonitor(alerts: alerts)
        let notifications = NotificationMirror(alerts: alerts)
        notifications.isFocusSilencing = { [weak focus] in
            Preferences.notificationsFollowFocus && focus?.active != nil
        }
        let islands = IslandsCoordinator(
            services: IslandServices(
                nowPlaying: nowPlaying,
                hud: hud,
                volume: volume,
                alerts: alerts,
                lyrics: lyrics,
                weather: weather,
                shelf: shelf,
                clipboard: clipboard,
                calendar: calendar,
                screenshots: screenshots,
                timers: timers,
                systemTimers: systemTimers,
                transfers: transfers,
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
            clipboard: clipboard,
            calendar: calendar,
            screenshots: screenshots,
            timers: timers,
            systemTimers: systemTimers,
            transfers: transfers,
            privacy: privacy,
            keyboard: KeyboardMonitor(alerts: alerts),
            presentation: PresentationDetector(alerts: alerts),
            energy: energy,
            focus: focus,
            unlock: UnlockGreeter(alerts: alerts),
            siri: SiriMonitor(alerts: alerts),
            notifications: notifications,
            desktopWidget: DesktopWidgetController(
                player: nowPlaying.model,
                weather: weather.model,
                actions: cardActions
            ),
            lockScreen: LockScreenController(player: nowPlaying.model, lyrics: lyrics.model, actions: cardActions),
            islands: islands,
            loginItem: LoginItemController(),
            updates: UpdateChecker()
        )
        self.features = features
        statusItem = StatusItemController(features: features)

        nowPlaying.start()
        hud.start()
        weather.start()
        shelf.start()
        clipboard.start()
        calendar.start()
        screenshots.start()
        transfers.start()
        systemTimers.start()
        privacy.start()
        focus.start()
        features.unlock.start()
        features.siri.start()
        features.notifications.start()
        features.keyboard.start()
        features.presentation.start()
        features.desktopWidget.start()
        features.lockScreen.start()
        if Preferences.lyricsEnabled { lyrics.start() }
        if Preferences.chargingAlertsEnabled { features.power.start() }
        if Preferences.headphoneAlertsEnabled { features.audioDevices.start() }
        // AirPods models for the volume HUD and the headphones' banner.
        Task { await BluetoothProduct.refreshIDs() }
        Diagnostics.shared.record("Halo avviato, versione \(Diagnostics.build)")
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
        features.transfers.stop()
        features.clipboard.stop()
        features.systemTimers.stop()
        features.privacy.stop()
        features.keyboard.stop()
        features.presentation.stop()
        features.focus.stop()
        features.unlock.stop()
        features.siri.stop()
    }

    /// SIGTERM and SIGINT would end the process without `applicationWillTerminate`,
    /// leaving the adapter and `log stream` children running. Route them through a
    /// normal quit instead. A crash still orphans them.
    private func quitOnSignals() {
        for number in [SIGTERM, SIGINT] {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler {
                MainActor.assumeIsolated { NSApp.terminate(nil) }
            }
            source.resume()
            signalSources.append(source)
        }
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
    let clipboard: ClipboardHistory
    let calendar: CalendarController
    let screenshots: ScreenshotController
    let timers: TimerController
    let systemTimers: SystemTimerMonitor
    let transfers: TransferMonitor
    let privacy: PrivacyIndicators
    let keyboard: KeyboardMonitor
    let presentation: PresentationDetector
    let energy: EnergyMode
    let focus: FocusMonitor
    let unlock: UnlockGreeter
    let siri: SiriMonitor
    let notifications: NotificationMirror
    let desktopWidget: DesktopWidgetController
    let lockScreen: LockScreenController
    let islands: IslandsCoordinator
    let loginItem: LoginItemController
    let updates: UpdateChecker
}
