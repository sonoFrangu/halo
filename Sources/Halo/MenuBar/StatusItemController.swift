import AppKit

/// The menu bar item: status, feature toggles, "Avvia al login", "Esci".
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let features: Features
    private let statusLine = NSMenuItem()
    private var toggles: [ToggleMenuItem] = []
    private var hudPermissionItem: NSMenuItem?
    private var notificationsPermissionItem: NSMenuItem?

    init(features: Features) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.features = features
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

        let hud = features.hud
        menu.addItem(toggle("HUD luminosità e volume nella notch", isOn: { hud.isEnabled }) { on in
            hud.setEnabled(on)
        })
        let permission = ActionMenuItem(title: "Concedi Accessibilità per l'HUD…") {
            hud.requestPermission()
        }
        hudPermissionItem = permission
        menu.addItem(permission)

        let lyrics = features.lyrics
        menu.addItem(toggle("Testi sincronizzati", isOn: { Preferences.lyricsEnabled }) { on in
            Preferences.lyricsEnabled = on
            if on { lyrics.start() } else { lyrics.stop() }
        })

        let weather = features.weather
        menu.addItem(toggle("Meteo", isOn: { weather.isEnabled }) { on in
            weather.setEnabled(on)
        })

        let shelf = features.shelf
        menu.addItem(toggle("Scaffale file", isOn: { shelf.isEnabled }) { on in
            shelf.setEnabled(on)
        })

        let calendar = features.calendar
        menu.addItem(toggle("Calendario", isOn: { calendar.isEnabled }) { on in
            calendar.setEnabled(on)
        })

        let notifications = features.notifications
        menu.addItem(toggle("Notifiche nella notch", isOn: { notifications.isEnabled }) { on in
            notifications.setEnabled(on)
        })
        let fullDiskAccess = ActionMenuItem(title: "Concedi Accesso completo al disco…") {
            notifications.openFullDiskAccessSettings()
        }
        notificationsPermissionItem = fullDiskAccess
        menu.addItem(fullDiskAccess)

        let lockScreen = features.lockScreen
        menu.addItem(toggle("Musica sulla schermata di blocco", isOn: { lockScreen.isEnabled }) { on in
            lockScreen.setEnabled(on)
        })

        let desktopWidget = features.desktopWidget
        menu.addItem(toggle("Widget sul desktop", isOn: { desktopWidget.isEnabled }) { on in
            desktopWidget.setEnabled(on)
        })

        let power = features.power
        menu.addItem(toggle("Avvisi di ricarica e batteria", isOn: { Preferences.chargingAlertsEnabled }) { on in
            Preferences.chargingAlertsEnabled = on
            if on { power.start() } else { power.stop() }
        })

        let audioDevices = features.audioDevices
        menu.addItem(toggle("Avvisi AirPods e cuffie", isOn: { Preferences.headphoneAlertsEnabled }) { on in
            Preferences.headphoneAlertsEnabled = on
            if on { audioDevices.start() } else { audioDevices.stop() }
        })

        let islands = features.islands
        menu.addItem(toggle("Su tutti i display", isOn: { Preferences.showsOnAllDisplays }) { on in
            Preferences.showsOnAllDisplays = on
            islands.rebuild()
        })

        menu.addItem(.separator())
        let loginItem = features.loginItem
        menu.addItem(toggle("Avvia al login", isOn: { loginItem.isEnabled }) { [weak self] on in
            self?.setLaunchAtLogin(on)
        })
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(title: "Esci", keyEquivalent: "q") {
            NSApp.terminate(nil)
        })
        return menu
    }

    private func toggle(_ title: String, isOn: @escaping () -> Bool, setOn: @escaping (Bool) -> Void) -> ToggleMenuItem {
        let item = ToggleMenuItem(title: title, isOn: isOn, setOn: setOn)
        toggles.append(item)
        return item
    }

    // MARK: NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        statusLine.title = statusText
        statusLine.toolTip = statusTooltip
        hudPermissionItem?.isHidden = features.hud.status != .needsPermission
        features.notifications.refreshAccess()
        notificationsPermissionItem?.isHidden = features.notifications.status != .needsFullDiskAccess
        for item in toggles {
            item.refresh()
        }
    }

    // MARK: Actions

    private func setLaunchAtLogin(_ enable: Bool) {
        let loginItem = features.loginItem
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
