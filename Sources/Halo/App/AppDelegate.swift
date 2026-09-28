import AppKit

/// Composition root: creates the Now Playing pipeline, the island and the menu bar item.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var nowPlaying: NowPlayingController?
    private var hud: HUDController?
    private var island: IslandController?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let nowPlaying = NowPlayingController(model: NowPlayingModel())
        let hud = HUDController()
        self.nowPlaying = nowPlaying
        self.hud = hud
        island = IslandController(nowPlaying: nowPlaying, hud: hud)
        statusItem = StatusItemController(player: nowPlaying.model, hud: hud, loginItem: LoginItemController())
        nowPlaying.start()
        hud.start()
        Log.app.info("Halo started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        nowPlaying?.stop()
        hud?.stop()
    }
}
