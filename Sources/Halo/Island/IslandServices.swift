import AppKit

/// Shared app services every island (one per display) reads from and acts on.
@MainActor
struct IslandServices {
    let nowPlaying: NowPlayingController
    let hud: HUDController
    let alerts: AlertCenter
    let lyrics: LyricsController
    let weather: WeatherController
    let shelf: ShelfController
    let calendar: CalendarController
    let screenshots: ScreenshotController
    let timers: TimerController
    let transfers: TransferMonitor
    let privacy: PrivacyIndicators
    let energy: EnergyMode

    /// What happens when an alert is clicked: a notification opens its app, a meeting
    /// reminder joins the call (or opens Calendar), a screenshot or a finished download
    /// opens; any alert is then dismissed.
    func activate(_ alert: IslandAlert) {
        switch alert {
        case .notification(let notification):
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: notification.bundleIdentifier) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }
        case .calendar(let reminder):
            calendar.open(reminder.event)
        case .screenshot(let capture):
            screenshots.open(capture.url)
        case .transfer(let transfer):
            transfers.open(transfer.url)
        case .hud, .power, .audioDevice, .timer, .keyboard, .focus, .unlock:
            break
        }
        alerts.dismissCurrent()
    }

    /// An island opened: a good moment to refresh what is only shown when open.
    func islandDidExpand() {
        weather.refreshIfStale()
    }
}
