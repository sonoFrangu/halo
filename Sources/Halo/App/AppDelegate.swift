import AppKit

/// Composition root: creates the Now Playing pipeline, the island and the menu bar item.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var nowPlaying: NowPlayingController?
    private var island: IslandController?
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let nowPlaying = NowPlayingController(model: NowPlayingModel())
        self.nowPlaying = nowPlaying
        island = IslandController(nowPlaying: nowPlaying)
        statusItem = StatusItemController(player: nowPlaying.model, loginItem: LoginItemController())
        nowPlaying.start()
        Log.app.info("Halo started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        nowPlaying?.stop()
    }
}
