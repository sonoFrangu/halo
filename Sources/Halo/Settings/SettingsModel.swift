import ApplicationServices
import CoreLocation
import Observation
import SwiftUI

/// The pages of the Settings window, in sidebar order.
enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case island
    case music
    case activities
    case alerts
    case files
    case permissions
    case about

    var id: String { rawValue }

    static let features: [SettingsPane] = [.general, .island, .music, .activities, .alerts, .files]

    var title: String {
        switch self {
        case .general: "Generale"
        case .island: "Isola"
        case .music: "Musica"
        case .activities: "Attività"
        case .alerts: "Avvisi"
        case .files: "Scaffale e screenshot"
        case .permissions: "Permessi"
        case .about: "Informazioni"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .island: "capsule.fill"
        case .music: "music.note"
        case .activities: "timer"
        case .alerts: "bell.badge.fill"
        case .files: "tray.full.fill"
        case .permissions: "hand.raised.fill"
        case .about: "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general: SettingsColor.gray
        case .island: SettingsColor.indigo
        case .music: SettingsColor.pink
        case .activities: SettingsColor.orange
        case .alerts: SettingsColor.red
        case .files: SettingsColor.teal
        case .permissions: SettingsColor.blue
        case .about: SettingsColor.gray
        }
    }

    /// What the page is about, under its title.
    var summary: String {
        switch self {
        case .general:
            "Come e dove appare Halo. L'isola vive nella notch: passaci sopra con il puntatore per aprirla, allontanati per chiuderla."
        case .island:
            "Cosa puoi fare con l'isola aperta e cosa mostra nella parte alta, accanto alla notch."
        case .music:
            "Il player si attiva da solo quando suona qualcosa in Musica, Spotify, Safari o in un altro player. Qui scegli testi, schermata di blocco e widget."
        case .activities:
            "Come le Live Activity di iPhone: timer, cronometro, riunioni e download restano visibili nelle ali della notch finché servono."
        case .alerts:
            "Brevi avvisi che compaiono nella notch e spariscono da soli dopo qualche secondo. Con il puntatore sopra restano finché li leggi."
        case .files:
            "Un posto temporaneo per i file, sempre a portata di mano nella notch."
        case .permissions:
            "Alcune funzioni hanno bisogno di un permesso di macOS. Halo funziona anche senza: la funzione che ne ha bisogno resta semplicemente inattiva."
        case .about:
            "La notch del tuo Mac, più viva."
        }
    }
}

enum SettingsColor {
    static let blue = Color(red: 0.04, green: 0.52, blue: 1)
    static let orange = Color(red: 1, green: 0.58, blue: 0)
    static let green = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let red = Color(red: 1, green: 0.23, blue: 0.19)
    static let purple = Color(red: 0.69, green: 0.32, blue: 0.87)
    static let pink = Color(red: 1, green: 0.18, blue: 0.33)
    static let teal = Color(red: 0.19, green: 0.69, blue: 0.78)
    static let indigo = Color(red: 0.35, green: 0.34, blue: 0.84)
    static let gray = Color(white: 0.55)
}

/// A macOS permission some features need.
enum SettingsPermission: CaseIterable, Identifiable {
    case accessibility
    case automation
    case fullDiskAccess
    case calendar
    case location

    var id: Self { self }

    var title: String {
        switch self {
        case .accessibility: "Accessibilità"
        case .automation: "Automazione (Spotify e Musica)"
        case .fullDiskAccess: "Accesso completo al disco"
        case .calendar: "Calendari"
        case .location: "Localizzazione"
        }
    }

    var symbol: String {
        switch self {
        case .accessibility: "accessibility"
        case .automation: "gearshape.2.fill"
        case .fullDiskAccess: "externaldrive.fill"
        case .calendar: "calendar"
        case .location: "location.fill"
        }
    }

    var tint: Color {
        switch self {
        case .accessibility: SettingsColor.blue
        case .automation: SettingsColor.purple
        case .fullDiskAccess: SettingsColor.gray
        case .calendar: SettingsColor.red
        case .location: SettingsColor.blue
        }
    }

    /// Which features use it, in plain words.
    var usage: String {
        switch self {
        case .accessibility:
            "Per luminosità e volume nella notch (Halo intercetta quei tasti) e per l'avviso di Bloc Maiusc. Serve anche come ultimo ripiego per play e pausa (il tasto multimediale)."
        case .automation:
            "Per mandare play, pausa, brani e posizione direttamente a Spotify e Musica: il modo più rapido e affidabile. macOS lo chiede al primo clic sul player; senza, Halo usa MediaRemote."
        case .fullDiskAccess:
            "Per le notifiche e la Full Immersione nella notch: macOS le tiene in file che solo le app con questo permesso possono leggere."
        case .calendar:
            "Per i prossimi impegni e l'avviso prima delle riunioni."
        case .location:
            "Per il meteo della tua zona (posizione approssimativa). Senza, Halo stima la città dall'indirizzo IP."
        }
    }
}

enum PermissionState: Equatable {
    case granted
    case missing
    /// macOS has not asked yet; it will when the feature first needs it.
    case notAsked
}

/// One on/off setting: what it does, where it shows, what it needs.
@MainActor
struct SettingsToggle: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    /// A permission without which the feature cannot work.
    var requires: SettingsPermission?
    /// Another setting that must be on for this one to matter.
    var dependsOn: String?
    let isOn: () -> Bool
    let setOn: (Bool) -> Void
}

/// A row of a settings page.
@MainActor
struct SettingsItem: Identifiable {
    enum Kind {
        case toggle(SettingsToggle)
        case hoverDelay
        case lyricsLead
    }

    let id: String
    let kind: Kind

    static func toggle(_ toggle: SettingsToggle) -> SettingsItem {
        SettingsItem(id: toggle.id, kind: .toggle(toggle))
    }

    static let hoverDelay = SettingsItem(id: "hoverDelay", kind: .hoverDelay)
    static let lyricsLead = SettingsItem(id: "lyricsLead", kind: .lyricsLead)
}

@MainActor
struct SettingsGroup: Identifiable {
    let id: String
    var title: String?
    var footer: String?
    let items: [SettingsItem]
}

/// State of the Settings window. Switches act on the live features; `revision` changes on
/// every edit (and when the window comes back to the front) so the window re-reads
/// values that are not observable themselves.
@MainActor
@Observable
final class SettingsModel {
    var pane: SettingsPane = .general
    private(set) var revision = 0

    @ObservationIgnored let groups: [SettingsPane: [SettingsGroup]]
    @ObservationIgnored private let features: Features
    @ObservationIgnored private let togglesByID: [String: SettingsToggle]
    @ObservationIgnored private lazy var locationManager = CLLocationManager()

    init(features: Features) {
        self.features = features
        let groups = Self.catalog(for: features)
        self.groups = groups
        var toggles: [String: SettingsToggle] = [:]
        for group in groups.values.joined() {
            for item in group.items {
                if case .toggle(let toggle) = item.kind {
                    toggles[toggle.id] = toggle
                }
            }
        }
        togglesByID = toggles
    }

    // MARK: Switches

    func isOn(_ toggle: SettingsToggle) -> Bool {
        _ = revision
        return toggle.isOn()
    }

    func set(_ toggle: SettingsToggle, _ on: Bool) {
        toggle.setOn(on)
        revision += 1
    }

    /// Whether the setting it depends on is on.
    func isAvailable(_ toggle: SettingsToggle) -> Bool {
        guard let parentID = toggle.dependsOn, let parent = togglesByID[parentID] else { return true }
        return isOn(parent)
    }

    func isOn(id: String) -> Bool {
        guard let toggle = togglesByID[id] else { return false }
        return isOn(toggle)
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

    /// Seconds lyrics are shown ahead of their timestamps.
    var lyricsLead: Double {
        _ = revision
        return features.lyrics.model.lead
    }

    func setLyricsLead(_ seconds: Double) {
        features.lyrics.model.setLead((seconds * 20).rounded() / 20)
        revision += 1
    }

    /// Re-reads what may have changed elsewhere (permissions granted in System Settings).
    func refresh() {
        features.notifications.refreshAccess()
        features.focus.refreshAccess()
        revision += 1
    }

    // MARK: Permissions

    func state(of permission: SettingsPermission) -> PermissionState {
        _ = revision
        switch permission {
        case .accessibility:
            return AXIsProcessTrusted() ? .granted : .missing
        case .automation:
            if !features.nowPlaying.automationDenied.isEmpty { return .missing }
            return features.nowPlaying.automationGranted ? .granted : .notAsked
        case .fullDiskAccess:
            return Self.hasFullDiskAccess ? .granted : .missing
        case .calendar:
            switch features.calendar.model.access {
            case .granted: return .granted
            case .denied: return .missing
            case .unknown: return .notAsked
            }
        case .location:
            switch locationManager.authorizationStatus {
            case .notDetermined: return .notAsked
            case .denied, .restricted: return .missing
            default: return .granted
            }
        }
    }

    var missingPermissions: [SettingsPermission] {
        SettingsPermission.allCases.filter { state(of: $0) == .missing && isNeeded($0) }
    }

    /// Whether a feature that is on uses it (location is optional: the weather falls back
    /// to the IP address).
    func isNeeded(_ permission: SettingsPermission) -> Bool {
        switch permission {
        case .accessibility: isOn(id: "hud") || isOn(id: "keyboard")
        case .automation: !features.nowPlaying.automationDenied.isEmpty
        case .fullDiskAccess: isOn(id: "notifications") || isOn(id: "focus")
        case .calendar: isOn(id: "calendar")
        case .location: false
        }
    }

    func grant(_ permission: SettingsPermission) {
        switch permission {
        case .accessibility:
            features.hud.requestPermission()
            Self.openPrivacyPane("Privacy_Accessibility")
        case .automation:
            Self.openPrivacyPane("Privacy_Automation")
        case .fullDiskAccess:
            Self.openPrivacyPane("Privacy_AllFiles")
        case .calendar:
            features.calendar.openPrivacySettings()
        case .location:
            Self.openPrivacyPane("Privacy_LocationServices")
        }
    }

    private static func openPrivacyPane(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens Notification Center's database, which only apps with Full Disk Access may
    /// read (no prompt is shown); the Focus store stands in if the database is missing.
    private static var hasFullDiskAccess: Bool {
        switch NotificationDatabase.checkAccess(to: NotificationDatabase.defaultURL) {
        case nil:
            return true
        case .permissionDenied?:
            return false
        default:
            return (try? FileManager.default.contentsOfDirectory(atPath: FocusStore.directory.path)) != nil
        }
    }

    // MARK: Catalog

    private static func catalog(for f: Features) -> [SettingsPane: [SettingsGroup]] {
        let islands = f.islands
        let hud = f.hud
        let lyrics = f.lyrics
        let weather = f.weather
        let calendar = f.calendar
        let timers = f.timers
        let transfers = f.transfers
        let shelf = f.shelf
        let screenshots = f.screenshots
        let power = f.power
        let audioDevices = f.audioDevices
        let notifications = f.notifications
        let focus = f.focus
        let unlock = f.unlock
        let privacy = f.privacy
        let keyboard = f.keyboard
        let desktopWidget = f.desktopWidget
        let lockScreen = f.lockScreen
        let presentation = f.presentation
        let energy = f.energy
        let loginItem = f.loginItem

        let general = [
            SettingsGroup(id: "startup", items: [
                .toggle(SettingsToggle(
                    id: "login", title: "Apri Halo al login",
                    detail: "Halo si avvia da solo quando accedi al Mac.",
                    symbol: "power", tint: SettingsColor.gray,
                    isOn: { loginItem.isEnabled },
                    setOn: { loginItem.setEnabledReportingErrors($0) }
                )),
                .toggle(SettingsToggle(
                    id: "displays", title: "Su tutti i display",
                    detail: "Un'isola anche sui monitor esterni e sui Mac senza notch, a forma di pillola in cima allo schermo.",
                    symbol: "display.2", tint: SettingsColor.blue,
                    isOn: { Preferences.showsOnAllDisplays },
                    setOn: { on in Preferences.showsOnAllDisplays = on; islands.rebuild() }
                )),
            ]),
            SettingsGroup(id: "opening", title: "Apertura", items: [.hoverDelay]),
            SettingsGroup(id: "quiet", title: "Discrezione ed energia", items: [
                .toggle(SettingsToggle(
                    id: "presentation", title: "Silenzio con app a tutto schermo",
                    detail: "Durante presentazioni, video e giochi a tutto schermo non compaiono notifiche e avvisi non urgenti. Timer, riunioni e batteria scarica sì.",
                    symbol: "play.rectangle.fill", tint: SettingsColor.indigo,
                    isOn: { presentation.isEnabled },
                    setOn: { presentation.setEnabled($0) }
                )),
                .toggle(SettingsToggle(
                    id: "energy", title: "Alleggerisci in risparmio energetico",
                    detail: "Con la modalità di basso consumo attiva: meno animazioni e aggiornamenti meno frequenti.",
                    symbol: "leaf.fill", tint: SettingsColor.green,
                    isOn: { energy.adapts },
                    setOn: { energy.setAdapts($0) }
                )),
            ]),
        ]

        let island = [
            SettingsGroup(id: "controls", title: "Controlli", items: [
                .toggle(SettingsToggle(
                    id: "hud", title: "Luminosità e volume nella notch",
                    detail: "Premendo i tasti di luminosità o volume il livello compare nella notch al posto del riquadro di sistema; puoi anche trascinare la barra.",
                    symbol: "sun.max.fill", tint: SettingsColor.orange, requires: .accessibility,
                    isOn: { hud.isEnabled },
                    setOn: { hud.setEnabled($0) }
                )),
                .toggle(SettingsToggle(
                    id: "gestures", title: "Gesti sul trackpad",
                    detail: "Sull'isola aperta: scorri a sinistra o a destra per cambiare brano, in su o in giù per il volume.",
                    symbol: "hand.draw.fill", tint: SettingsColor.indigo,
                    isOn: { Preferences.gesturesEnabled },
                    setOn: { Preferences.gesturesEnabled = $0 }
                )),
                .toggle(SettingsToggle(
                    id: "haptics", title: "Feedback aptico",
                    detail: "Una leggera vibrazione del trackpad quando un gesto va a segno.",
                    symbol: "waveform.path", tint: SettingsColor.gray, dependsOn: "gestures",
                    isOn: { Preferences.hapticsEnabled },
                    setOn: { Preferences.hapticsEnabled = $0 }
                )),
            ]),
            SettingsGroup(id: "header", title: "In alto a destra", items: [
                .toggle(SettingsToggle(
                    id: "weather", title: "Meteo",
                    detail: "Temperatura e cielo accanto alla notch quando l'isola è aperta (lascia il posto alla prossima riunione quando è vicina).",
                    symbol: "cloud.sun.fill", tint: SettingsColor.blue,
                    isOn: { weather.isEnabled },
                    setOn: { weather.setEnabled($0) }
                )),
            ]),
        ]

        let music = [
            SettingsGroup(id: "lyrics", title: "Testi", items: [
                .toggle(SettingsToggle(
                    id: "lyrics", title: "Testi sincronizzati",
                    detail: "Il pulsante con le virgolette nel player apre il testo che scorre a tempo di musica. I testi arrivano da LRCLIB; tocca una riga per saltare lì.",
                    symbol: "quote.bubble.fill", tint: SettingsColor.pink,
                    isOn: { Preferences.lyricsEnabled },
                    setOn: { on in Preferences.lyricsEnabled = on; if on { lyrics.start() } else { lyrics.stop() } }
                )),
                .lyricsLead,
            ]),
            SettingsGroup(id: "elsewhere", title: "Fuori dalla notch", items: [
                .toggle(SettingsToggle(
                    id: "lockScreen", title: "Sulla schermata di blocco",
                    detail: "Se blocchi il Mac mentre suona qualcosa, copertina, controlli e testo compaiono sulla schermata di blocco.",
                    symbol: "lock.fill", tint: SettingsColor.purple,
                    isOn: { lockScreen.isEnabled },
                    setOn: { lockScreen.setEnabled($0) }
                )),
                .toggle(SettingsToggle(
                    id: "desktopWidget", title: "Widget sulla scrivania",
                    detail: "Una scheda in vetro sulla scrivania: il player, oppure ora e meteo quando non suona nulla. Trascinala dove vuoi.",
                    symbol: "rectangle.on.rectangle", tint: SettingsColor.teal,
                    isOn: { desktopWidget.isEnabled },
                    setOn: { desktopWidget.setEnabled($0) }
                )),
            ]),
        ]

        let activities = [
            SettingsGroup(
                id: "live",
                footer: "Con la musica in riproduzione, l'attività prende il posto dell'equalizzatore nell'ala destra.",
                items: [
                    .toggle(SettingsToggle(
                        id: "timer", title: "Timer, Pomodoro e cronometro",
                        detail: "La scheda Timer nell'isola aperta (anche dal menu di Halo). Il tempo che scorre resta nelle ali della notch.",
                        symbol: "timer", tint: SettingsColor.orange,
                        isOn: { timers.isEnabled },
                        setOn: { timers.setEnabled($0) }
                    )),
                    .toggle(SettingsToggle(
                        id: "calendar", title: "Calendario e riunioni",
                        detail: "La scheda Calendario con i prossimi impegni e «Partecipa» per Zoom, Meet, Teams, Webex e FaceTime; un avviso 5 minuti prima.",
                        symbol: "calendar", tint: SettingsColor.red, requires: .calendar,
                        isOn: { calendar.isEnabled },
                        setOn: { calendar.setEnabled($0) }
                    )),
                    .toggle(SettingsToggle(
                        id: "transfers", title: "Download e AirDrop",
                        detail: "Mentre scarichi un file o ricevi qualcosa con AirDrop l'avanzamento compare nelle ali; alla fine un avviso porta al file.",
                        symbol: "arrow.down.circle.fill", tint: SettingsColor.green,
                        isOn: { transfers.isEnabled },
                        setOn: { transfers.setEnabled($0) }
                    )),
                    .toggle(SettingsToggle(
                        id: "privacy", title: "Microfono e fotocamera in uso",
                        detail: "Un pallino arancione (microfono) o verde (fotocamera) nelle ali finché un'app li usa.",
                        symbol: "mic.fill", tint: SettingsColor.orange,
                        isOn: { privacy.isEnabled },
                        setOn: { privacy.setEnabled($0) }
                    )),
                ]
            ),
        ]

        let alerts = [
            SettingsGroup(id: "notifications", title: "Notifiche e Full Immersione", items: [
                .toggle(SettingsToggle(
                    id: "notifications", title: "Notifiche nella notch",
                    detail: "Le notifiche delle app compaiono anche nella notch; un clic apre l'app. Il banner di macOS resta dov'è.",
                    symbol: "bell.badge.fill", tint: SettingsColor.red, requires: .fullDiskAccess,
                    isOn: { notifications.isEnabled },
                    setOn: { notifications.setEnabled($0) }
                )),
                .toggle(SettingsToggle(
                    id: "notificationsFollowFocus", title: "Silenzia durante una Full Immersione",
                    detail: "Mentre una Full Immersione è attiva le notifiche non compaiono nella notch.",
                    symbol: "moon.fill", tint: SettingsColor.indigo, dependsOn: "notifications",
                    isOn: { Preferences.notificationsFollowFocus },
                    setOn: { Preferences.notificationsFollowFocus = $0 }
                )),
                .toggle(SettingsToggle(
                    id: "focus", title: "Cambi di Full Immersione",
                    detail: "Attivando o disattivando una Full Immersione la notch mostra quale, con il suo simbolo. Solo quelle attivate a mano, non da programma.",
                    symbol: "moon.circle.fill", tint: SettingsColor.indigo, requires: .fullDiskAccess,
                    isOn: { focus.isEnabled },
                    setOn: { focus.setEnabled($0) }
                )),
            ]),
            SettingsGroup(id: "system", title: "Sistema", items: [
                .toggle(SettingsToggle(
                    id: "power", title: "Ricarica e batteria",
                    detail: "Quando colleghi o scolleghi l'alimentatore, e quando la batteria scende al 20, 10 e 5%.",
                    symbol: "battery.100percent.bolt", tint: SettingsColor.green,
                    isOn: { Preferences.chargingAlertsEnabled },
                    setOn: { on in Preferences.chargingAlertsEnabled = on; if on { power.start() } else { power.stop() } }
                )),
                .toggle(SettingsToggle(
                    id: "headphones", title: "AirPods e cuffie",
                    detail: "Alla connessione: le batterie di auricolari e custodia, e il volume.",
                    symbol: "airpodspro", tint: SettingsColor.gray,
                    isOn: { Preferences.headphoneAlertsEnabled },
                    setOn: { on in Preferences.headphoneAlertsEnabled = on; if on { audioDevices.start() } else { audioDevices.stop() } }
                )),
                .toggle(SettingsToggle(
                    id: "keyboard", title: "Lingua della tastiera e Bloc Maiusc",
                    detail: "Quando cambi lingua della tastiera o premi Bloc Maiusc (per Bloc Maiusc serve Accessibilità).",
                    symbol: "globe", tint: SettingsColor.blue,
                    isOn: { keyboard.isEnabled },
                    setOn: { keyboard.setEnabled($0) }
                )),
                .toggle(SettingsToggle(
                    id: "unlock", title: "Sblocco",
                    detail: "Il lucchetto che si apre nella notch quando sblocchi il Mac, come su iPhone.",
                    symbol: "lock.open.fill", tint: SettingsColor.gray,
                    isOn: { unlock.isEnabled },
                    setOn: { unlock.setEnabled($0) }
                )),
            ]),
        ]

        let files = [
            SettingsGroup(id: "files", items: [
                .toggle(SettingsToggle(
                    id: "shelf", title: "Scaffale",
                    detail: "Trascina dei file verso la notch: l'isola si apre sulla scheda Scaffale e li tiene lì, anche dopo un riavvio, finché non li trascini altrove.",
                    symbol: "tray.full.fill", tint: SettingsColor.teal,
                    isOn: { shelf.isEnabled },
                    setOn: { shelf.setEnabled($0) }
                )),
                .toggle(SettingsToggle(
                    id: "screenshots", title: "Anteprima degli screenshot",
                    detail: "Dopo uno screenshot una miniatura compare nella notch: trascinala dove vuoi, copiala, tienila sullo scaffale o cestinala.",
                    symbol: "camera.viewfinder", tint: SettingsColor.gray,
                    isOn: { screenshots.isEnabled },
                    setOn: { screenshots.setEnabled($0) }
                )),
            ]),
        ]

        return [
            .general: general,
            .island: island,
            .music: music,
            .activities: activities,
            .alerts: alerts,
            .files: files,
        ]
    }
}
