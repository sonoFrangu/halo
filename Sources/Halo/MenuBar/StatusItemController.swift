import AppKit

/// The menu bar item: what is playing, the timer, Settings, missing permissions, Quit.
/// Feature switches live in the Settings window.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let features: Features
    private let settings: SettingsWindowController
    private let statusLine = NSMenuItem()
    private var permissionsItem: NSMenuItem?
    private var playPauseItem: NSMenuItem?
    private var nextItem: NSMenuItem?
    private var timerPauseItem: NSMenuItem?
    private var timerStopItem: NSMenuItem?
    private var stopwatchItem: NSMenuItem?
    private var stopwatchResetItem: NSMenuItem?
    private var updateItem: NSMenuItem?
    private var updates: UpdateChecker { features.updates }

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
        updates.checkIfDue()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        statusLine.isEnabled = false
        menu.addItem(statusLine)

        let nowPlaying = features.nowPlaying
        let playPause = ActionMenuItem(title: "Play/Pausa") {
            Diagnostics.shared.record("menu: play/pausa")
            nowPlaying.togglePlayPause()
        }
        let next = ActionMenuItem(title: "Brano successivo") {
            nowPlaying.nextTrack()
        }
        playPauseItem = playPause
        nextItem = next
        menu.addItem(playPause)
        menu.addItem(next)
        menu.addItem(.separator())

        menu.addItem(timerMenuItem())
        let settings = self.settings
        menu.addItem(ActionMenuItem(title: "Impostazioni…", keyEquivalent: ",") {
            settings.show()
        })

        let permissions = ActionMenuItem(title: "Permessi mancanti…") {
            settings.show(pane: .permissions)
        }
        permissions.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
        permissionsItem = permissions
        menu.addItem(permissions)

        let updates = self.updates
        let update = ActionMenuItem(title: "Scarica l'aggiornamento…") {
            if let page = updates.available?.page {
                NSWorkspace.shared.open(page)
            }
        }
        update.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)
        update.isHidden = true
        updateItem = update
        menu.addItem(update)

        menu.addItem(ActionMenuItem(title: "Copia diagnostica") {
            Diagnostics.shared.copyReport()
        })

        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(title: "Esci da Halo", keyEquivalent: "q") {
            NSApp.terminate(nil)
        })
        return menu
    }

    /// "Timer ▸": presets and Pomodoro, then pause/stop for the running timer.
    private func timerMenuItem() -> NSMenuItem {
        let timers = features.timers
        let systemTimers = features.systemTimers
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for minutes in TimerController.presets {
            submenu.addItem(ActionMenuItem(title: "\(minutes) min") {
                TimerCommands.start(minutes: minutes, timers: timers, systemTimers: systemTimers)
            })
        }
        submenu.addItem(ActionMenuItem(title: "Pomodoro (25 + 5)") { timers.startPomodoro() })
        submenu.addItem(.separator())
        let pause = ActionMenuItem(title: "Pausa") { TimerCommands.togglePause(timers: timers, systemTimers: systemTimers) }
        let stop = ActionMenuItem(title: "Ferma") { TimerCommands.stop(timers: timers, systemTimers: systemTimers) }
        submenu.addItem(pause)
        submenu.addItem(stop)
        timerPauseItem = pause
        timerStopItem = stop

        submenu.addItem(.separator())
        let stopwatch = ActionMenuItem(title: "Avvia cronometro") { timers.toggleStopwatch() }
        let reset = ActionMenuItem(title: "Azzera cronometro") { timers.resetStopwatch() }
        submenu.addItem(stopwatch)
        submenu.addItem(reset)
        stopwatchItem = stopwatch
        stopwatchResetItem = reset

        let item = NSMenuItem(title: "Timer e cronometro", action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    // MARK: NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        statusLine.title = statusText
        statusLine.toolTip = statusTooltip
        let snapshot = features.player.snapshot
        playPauseItem?.isEnabled = snapshot != nil
        playPauseItem?.title = snapshot?.isPlaying == true ? "Pausa" : "Riproduci"
        nextItem?.isEnabled = snapshot != nil
        features.notifications.refreshAccess()
        features.focus.refreshAccess()
        updates.checkIfDue()
        updateItem?.isHidden = updates.available == nil
        if let release = updates.available {
            updateItem?.title = "Scarica Halo \(release.version)…"
        }
        let missing = settings.missingPermissions
        permissionsItem?.isHidden = missing.isEmpty
        permissionsItem?.title = missing.count == 1
            ? "Concedi «\(missing[0].title)»…"
            : "Concedi \(missing.count) permessi mancanti…"
        let timer = TimerCommands.shown(timers: features.timers, systemTimers: features.systemTimers)
        timerPauseItem?.isEnabled = timer != nil
        timerPauseItem?.title = timer?.isRunning == false ? "Riprendi" : "Pausa"
        timerStopItem?.isEnabled = timer != nil
        let stopwatch = features.timers.stopwatch
        let stopwatchTitle: String = switch stopwatch?.isRunning {
        case true?: "Metti in pausa il cronometro"
        case false?: "Riprendi il cronometro"
        case nil: "Avvia cronometro"
        }
        stopwatchItem?.title = stopwatchTitle
        stopwatchResetItem?.isEnabled = stopwatch != nil
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
