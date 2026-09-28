import AppKit

/// The menu bar item: what is playing, the timer, Settings, missing permissions, Quit.
/// Feature switches live in the Settings window.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let features: Features
    private let settings: SettingsWindowController
    private let statusLine = NSMenuItem()
    private var hudPermissionItem: NSMenuItem?
    private var notificationsPermissionItem: NSMenuItem?
    private var timerPauseItem: NSMenuItem?
    private var timerStopItem: NSMenuItem?

    init(features: Features) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.features = features
        self.settings = SettingsWindowController(features: features)
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
        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())

        menu.addItem(timerMenuItem())
        let settings = self.settings
        menu.addItem(ActionMenuItem(title: "Impostazioni…", keyEquivalent: ",") {
            settings.show()
        })

        let hud = features.hud
        let accessibility = ActionMenuItem(title: "Concedi Accessibilità per l'HUD…") {
            hud.requestPermission()
        }
        hudPermissionItem = accessibility
        menu.addItem(accessibility)

        let notifications = features.notifications
        let fullDiskAccess = ActionMenuItem(title: "Concedi Accesso completo al disco…") {
            notifications.openFullDiskAccessSettings()
        }
        notificationsPermissionItem = fullDiskAccess
        menu.addItem(fullDiskAccess)

        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(title: "Esci da Halo", keyEquivalent: "q") {
            NSApp.terminate(nil)
        })
        return menu
    }

    /// "Timer ▸": presets and Pomodoro, then pause/stop for the running timer.
    private func timerMenuItem() -> NSMenuItem {
        let timers = features.timers
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for minutes in TimerController.presets {
            submenu.addItem(ActionMenuItem(title: "\(minutes) min") { timers.start(minutes: minutes) })
        }
        submenu.addItem(ActionMenuItem(title: "Pomodoro (25 + 5)") { timers.startPomodoro() })
        submenu.addItem(.separator())
        let pause = ActionMenuItem(title: "Pausa") { timers.togglePause() }
        let stop = ActionMenuItem(title: "Ferma") { timers.stop() }
        submenu.addItem(pause)
        submenu.addItem(stop)
        timerPauseItem = pause
        timerStopItem = stop

        let item = NSMenuItem(title: "Timer", action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    // MARK: NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        statusLine.title = statusText
        statusLine.toolTip = statusTooltip
        hudPermissionItem?.isHidden = features.hud.status != .needsPermission
        features.notifications.refreshAccess()
        notificationsPermissionItem?.isHidden = features.notifications.status != .needsFullDiskAccess
        let timer = features.timers.timer
        timerPauseItem?.isEnabled = timer != nil
        timerPauseItem?.title = timer?.isRunning == false ? "Riprendi" : "Pausa"
        timerStopItem?.isEnabled = timer != nil
    }

    // MARK: Status

    private var statusText: String {
        let player = features.player
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
        if case .unavailable(let reason) = features.player.availability {
            return reason
        }
        return nil
    }
}
