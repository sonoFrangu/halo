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

    /// What happens when an alert is clicked: a notification opens its app; any alert is
    /// dismissed.
    func activate(_ alert: IslandAlert) {
        if case .notification(let notification) = alert,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: notification.bundleIdentifier) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        alerts.dismissCurrent()
    }

    /// An island opened: a good moment to refresh what is only shown when open.
    func islandDidExpand() {
        weather.refreshIfStale()
    }
}
