import Observation
import SwiftUI

/// One on/off setting: how to read it and what switching it does.
@MainActor
struct SettingsToggle: Identifiable {
    let id: String
    let title: String
    var detail: String?
    let symbol: String
    let tint: Color
    let isOn: () -> Bool
    let setOn: (Bool) -> Void
}

@MainActor
struct SettingsSection: Identifiable {
    let id: String
    let title: String
    let toggles: [SettingsToggle]
}

/// State of the Settings window. Switches act on the live features; `revision` changes on
/// every edit so the window re-reads values that are not observable themselves.
@MainActor
@Observable
final class SettingsModel {
    let sections: [SettingsSection]
    private(set) var revision = 0
    @ObservationIgnored private let features: Features

    init(features: Features) {
        self.features = features
        self.sections = Self.sections(for: features)
    }

    func isOn(_ toggle: SettingsToggle) -> Bool {
        _ = revision
        return toggle.isOn()
    }

    func set(_ toggle: SettingsToggle, _ on: Bool) {
        toggle.setOn(on)
        revision += 1
    }

    /// Seconds before the island opens under the pointer.
    var hoverDelay: Double {
        _ = revision
        return Preferences.hoverDelay
    }

    func setHoverDelay(_ seconds: Double) {
        Preferences.hoverDelay = seconds
        revision += 1
    }

    /// Re-reads permissions (the window just opened; the user may have changed them).
    func refresh() {
        features.notifications.refreshAccess()
        revision += 1
    }

    // MARK: Permissions

    var needsAccessibility: Bool {
        _ = revision
        return features.hud.status == .needsPermission
    }

    var needsFullDiskAccess: Bool {
        _ = revision
        return features.notifications.status == .needsFullDiskAccess
    }

    var calendarDenied: Bool {
        features.calendar.model.access == .denied
    }

    func requestAccessibility() {
        features.hud.requestPermission()
    }

    func openFullDiskAccess() {
        features.notifications.openFullDiskAccessSettings()
    }

    func openCalendarPrivacy() {
        features.calendar.openPrivacySettings()
    }

    // MARK: Catalog

    private static func sections(for f: Features) -> [SettingsSection] {
        let blue = Color(red: 0.04, green: 0.52, blue: 1)
        let orange = Color(red: 1, green: 0.58, blue: 0)
        let green = Color(red: 0.2, green: 0.78, blue: 0.35)
        let red = Color(red: 1, green: 0.23, blue: 0.19)
        let purple = Color(red: 0.69, green: 0.32, blue: 0.87)
        let pink = Color(red: 1, green: 0.18, blue: 0.33)
        let teal = Color(red: 0.19, green: 0.69, blue: 0.78)
        let indigo = Color(red: 0.35, green: 0.34, blue: 0.84)
        let gray = Color(white: 0.55)

        let islands = f.islands
        let hud = f.hud
        let lyrics = f.lyrics
        let weather = f.weather
        let calendar = f.calendar
        let timers = f.timers
        let shelf = f.shelf
        let screenshots = f.screenshots
        let power = f.power
        let audioDevices = f.audioDevices
        let notifications = f.notifications
        let privacy = f.privacy
        let keyboard = f.keyboard
        let desktopWidget = f.desktopWidget
        let lockScreen = f.lockScreen
        let presentation = f.presentation
        let energy = f.energy
        let loginItem = f.loginItem

        let sections: [SettingsSection] = [
            SettingsSection(id: "island", title: "Isola", toggles: [
                SettingsToggle(
                    id: "displays", title: "Su tutti i display", detail: "Monitor esterni e Mac senza notch",
                    symbol: "display.2", tint: blue,
                    isOn: { Preferences.showsOnAllDisplays },
                    setOn: { on in Preferences.showsOnAllDisplays = on; islands.rebuild() }
                ),
                SettingsToggle(
                    id: "gestures", title: "Gesti", detail: "Scorri per cambiare brano e volume",
                    symbol: "hand.draw.fill", tint: indigo,
                    isOn: { Preferences.gesturesEnabled },
                    setOn: { Preferences.gesturesEnabled = $0 }
                ),
                SettingsToggle(
                    id: "haptics", title: "Feedback aptico", detail: "Sul trackpad Force Touch",
                    symbol: "waveform.path", tint: gray,
                    isOn: { Preferences.hapticsEnabled },
                    setOn: { Preferences.hapticsEnabled = $0 }
                ),
            ]),
            SettingsSection(id: "music", title: "Musica", toggles: [
                SettingsToggle(
                    id: "lyrics", title: "Testi sincronizzati", detail: "Da LRCLIB",
                    symbol: "quote.bubble.fill", tint: pink,
                    isOn: { Preferences.lyricsEnabled },
                    setOn: { on in Preferences.lyricsEnabled = on; if on { lyrics.start() } else { lyrics.stop() } }
                ),
                SettingsToggle(
                    id: "lockScreen", title: "Schermata di blocco", detail: "Player e testi quando blocchi il Mac",
                    symbol: "lock.fill", tint: purple,
                    isOn: { lockScreen.isEnabled },
                    setOn: { lockScreen.setEnabled($0) }
                ),
                SettingsToggle(
                    id: "desktopWidget", title: "Widget sul desktop", detail: "Player, oppure ora e meteo",
                    symbol: "rectangle.on.rectangle", tint: teal,
                    isOn: { desktopWidget.isEnabled },
                    setOn: { desktopWidget.setEnabled($0) }
                ),
            ]),
            SettingsSection(id: "notch", title: "Nella notch", toggles: [
                SettingsToggle(
                    id: "hud", title: "Luminosità e volume", detail: "Sostituisce l'HUD di sistema",
                    symbol: "sun.max.fill", tint: orange,
                    isOn: { hud.isEnabled },
                    setOn: { hud.setEnabled($0) }
                ),
                SettingsToggle(
                    id: "weather", title: "Meteo", symbol: "cloud.sun.fill", tint: blue,
                    isOn: { weather.isEnabled },
                    setOn: { weather.setEnabled($0) }
                ),
                SettingsToggle(
                    id: "calendar", title: "Calendario", detail: "Prossimi impegni e promemoria riunioni",
                    symbol: "calendar", tint: red,
                    isOn: { calendar.isEnabled },
                    setOn: { calendar.setEnabled($0) }
                ),
                SettingsToggle(
                    id: "timer", title: "Timer e Pomodoro", symbol: "timer", tint: orange,
                    isOn: { timers.isEnabled },
                    setOn: { timers.setEnabled($0) }
                ),
                SettingsToggle(
                    id: "shelf", title: "Scaffale file", detail: "Trascina i file sulla notch",
                    symbol: "tray.full.fill", tint: teal,
                    isOn: { shelf.isEnabled },
                    setOn: { shelf.setEnabled($0) }
                ),
                SettingsToggle(
                    id: "screenshots", title: "Anteprima screenshot", symbol: "camera.viewfinder", tint: gray,
                    isOn: { screenshots.isEnabled },
                    setOn: { screenshots.setEnabled($0) }
                ),
            ]),
            SettingsSection(id: "alerts", title: "Avvisi", toggles: [
                SettingsToggle(
                    id: "power", title: "Ricarica e batteria", symbol: "battery.100percent.bolt", tint: green,
                    isOn: { Preferences.chargingAlertsEnabled },
                    setOn: { on in Preferences.chargingAlertsEnabled = on; if on { power.start() } else { power.stop() } }
                ),
                SettingsToggle(
                    id: "headphones", title: "AirPods e cuffie", detail: "Batterie e volume alla connessione",
                    symbol: "airpodspro", tint: gray,
                    isOn: { Preferences.headphoneAlertsEnabled },
                    setOn: { on in Preferences.headphoneAlertsEnabled = on; if on { audioDevices.start() } else { audioDevices.stop() } }
                ),
                SettingsToggle(
                    id: "notifications", title: "Notifiche", detail: "Richiede l'Accesso completo al disco",
                    symbol: "bell.badge.fill", tint: red,
                    isOn: { notifications.isEnabled },
                    setOn: { notifications.setEnabled($0) }
                ),
                SettingsToggle(
                    id: "privacy", title: "Microfono e fotocamera in uso", symbol: "mic.fill", tint: orange,
                    isOn: { privacy.isEnabled },
                    setOn: { privacy.setEnabled($0) }
                ),
                SettingsToggle(
                    id: "keyboard", title: "Lingua tastiera e Bloc Maiusc", symbol: "globe", tint: blue,
                    isOn: { keyboard.isEnabled },
                    setOn: { keyboard.setEnabled($0) }
                ),
            ]),
            SettingsSection(id: "focus", title: "Concentrazione ed energia", toggles: [
                SettingsToggle(
                    id: "presentation", title: "Silenzio con app a tutto schermo",
                    detail: "Presentazioni, video e chiamate senza interruzioni",
                    symbol: "play.rectangle.fill", tint: indigo,
                    isOn: { presentation.isEnabled },
                    setOn: { presentation.setEnabled($0) }
                ),
                SettingsToggle(
                    id: "energy", title: "Alleggerisci in risparmio energetico",
                    detail: "Meno animazioni con la modalità di basso consumo",
                    symbol: "leaf.fill", tint: green,
                    isOn: { energy.adapts },
                    setOn: { energy.setAdapts($0) }
                ),
            ]),
            SettingsSection(id: "general", title: "Generale", toggles: [
                SettingsToggle(
                    id: "login", title: "Avvia al login", symbol: "power", tint: gray,
                    isOn: { loginItem.isEnabled },
                    setOn: { loginItem.setEnabledReportingErrors($0) }
                ),
            ]),
        ]
        return sections
    }
}
