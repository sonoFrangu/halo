import AppKit

/// The menu bar item: current status, "Avvia al login", "Esci".
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let player: NowPlayingModel
    private let loginItem: LoginItemController
    private let statusLine = NSMenuItem()
    private let launchAtLoginItem = NSMenuItem()

    init(player: NowPlayingModel, loginItem: LoginItemController) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.player = player
        self.loginItem = loginItem
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Halo")
            image?.isTemplate = true
            button.image = image
            if image == nil {
                button.title = "Halo"
            }
            button.toolTip = "Halo"
        }

        statusLine.isEnabled = false

        launchAtLoginItem.title = "Avvia al login"
        launchAtLoginItem.target = self
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin(_:))

        let quitItem = NSMenuItem(title: "Esci", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        menu.addItem(statusLine)
        menu.addItem(.separator())
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    // MARK: NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        statusLine.title = statusText
        statusLine.toolTip = statusTooltip
        launchAtLoginItem.state = loginItem.isEnabled ? .on : .off
    }

    // MARK: Actions

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let enable = !loginItem.isEnabled
        do {
            try loginItem.setEnabled(enable)
            if enable && loginItem.requiresApproval {
                loginItem.openSystemSettings()
            }
        } catch {
            Log.app.error("login item update failed: \(error.localizedDescription, privacy: .public)")
            let alert = NSAlert()
            alert.messageText = enable ? "Impossibile attivare l'avvio al login" : "Impossibile disattivare l'avvio al login"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Apri Impostazioni")
            NSApp.activate()
            if alert.runModal() == .alertSecondButtonReturn {
                loginItem.openSystemSettings()
            }
        }
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    // MARK: Status

    private var statusText: String {
        switch player.availability {
        case .unavailable:
            return "Now Playing non disponibile"
        case .starting:
            return "Now Playing in avvio…"
        case .running:
            guard let snapshot = player.snapshot else { return "Niente in riproduzione" }
            let artist = snapshot.artist.map { " — \($0)" } ?? ""
            let prefix = snapshot.isPlaying ? "In riproduzione" : "In pausa"
            return "\(prefix): \(snapshot.title)\(artist)"
        }
    }

    private var statusTooltip: String? {
        if case .unavailable(let reason) = player.availability {
            return reason
        }
        return nil
    }
}
