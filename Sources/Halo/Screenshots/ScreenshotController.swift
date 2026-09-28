import AppKit

/// Shows each new screenshot in the island: drag it straight into a chat or a document,
/// copy it, keep it on the shelf or throw it away.
@MainActor
final class ScreenshotController {
    private let alerts: AlertCenter
    private let shelf: ShelfStore
    private var watcher: ScreenshotWatcher?
    private(set) var isEnabled = Preferences.screenshotsEnabled

    init(alerts: AlertCenter, shelf: ShelfStore) {
        self.alerts = alerts
        self.shelf = shelf
    }

    func start() {
        guard isEnabled, watcher == nil else { return }
        let watcher = ScreenshotWatcher { [weak self] url in
            self?.captured(url)
        }
        watcher.start()
        self.watcher = watcher
    }

    func stop() {
        watcher?.stop()
        watcher = nil
        alerts.withdraw(.screenshot)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.screenshotsEnabled = enabled
        if enabled { start() } else { stop() }
    }

    // MARK: Actions

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
        alerts.dismissCurrent()
    }

    /// Copies the image, ready to paste into a message or a document.
    func copy(_ url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        Haptics.perform(.action)
        alerts.dismissCurrent()
    }

    func keepOnShelf(_ url: URL) {
        shelf.add([url])
        Haptics.perform(.action)
        alerts.dismissCurrent()
    }

    func moveToTrash(_ url: URL) {
        NSWorkspace.shared.recycle([url], completionHandler: nil)
        Haptics.perform(.action)
        alerts.dismissCurrent()
    }

    private func captured(_ url: URL) {
        alerts.post(.screenshot(ScreenshotAlert(url: url)))
    }
}
