import AppKit
import SwiftUI

/// The Settings window, laid out like System Settings: pages in a sidebar; on each page a
/// short explanation, then every option with what it does, where it shows and what it
/// needs. Missing permissions are flagged where they matter and gathered on their page.
struct SettingsView: View {
    let model: SettingsModel

    var body: some View {
        NavigationSplitView {
            List(selection: Binding<SettingsPane?>(get: { model.pane }, set: { model.pane = $0 ?? .general })) {
                Section {
                    ForEach(SettingsPane.features) { pane in
                        SidebarRow(pane: pane).tag(pane)
                    }
                }
                Section {
                    SidebarRow(pane: .permissions, badge: model.missingPermissions.count).tag(SettingsPane.permissions)
                    SidebarRow(pane: .about).tag(SettingsPane.about)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 240)
        } detail: {
            SettingsPage(model: model, pane: model.pane)
        }
        .frame(minWidth: 760, idealWidth: 800, minHeight: 560, idealHeight: 640)
    }
}

struct SidebarRow: View {
    let pane: SettingsPane
    var badge = 0

    var body: some View {
        Label {
            Text(pane.title)
        } icon: {
            SettingsIcon(symbol: pane.symbol, tint: pane.tint, size: 20)
        }
        .badge(badge)
    }
}

/// One page: its header, then its groups (or the permissions, or the credits).
struct SettingsPage: View {
    let model: SettingsModel
    let pane: SettingsPane

    var body: some View {
        Form {
            Section {
                PageHeader(pane: pane)
            }
            switch pane {
            case .permissions:
                PermissionsSection(model: model)
            case .about:
                AboutSection()
            default:
                ForEach(model.groups[pane] ?? []) { group in
                    Section {
                        ForEach(group.items) { item in
                            SettingsItemRow(model: model, item: item)
                        }
                    } header: {
                        if let title = group.title {
                            Text(title)
                        }
                    } footer: {
                        if let footer = group.footer {
                            Text(footer)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(pane.title)
    }
}

/// Big icon, title and a sentence about the page.
struct PageHeader: View {
    let pane: SettingsPane

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if pane == .about {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
            } else {
                SettingsIcon(symbol: pane.symbol, tint: pane.tint, size: 44)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(pane == .about ? "Halo \(Self.version)" : pane.title)
                    .font(.system(size: 17, weight: .semibold))
                Text(pane.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }
}

struct SettingsItemRow: View {
    let model: SettingsModel
    let item: SettingsItem

    var body: some View {
        switch item.kind {
        case .toggle(let toggle):
            SettingsToggleRow(model: model, toggle: toggle)
        case .hoverDelay:
            HoverDelayRow(model: model)
        case .lyricsLead:
            LyricsLeadRow(model: model)
        case .timerApp:
            TimerAppRow(model: model)
        }
    }
}

/// A feature switch: colored icon, name, explanation; the permission it lacks, if any,
/// with the button that fixes it.
struct SettingsToggleRow: View {
    let model: SettingsModel
    let toggle: SettingsToggle

    var body: some View {
        let isOn = model.isOn(toggle)
        let available = model.isAvailable(toggle)
        let missing = toggle.requires.flatMap { model.state(of: $0) == .missing ? $0 : nil }

        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { model.isOn(toggle) }, set: { model.set(toggle, $0) })) {
                HStack(alignment: .top, spacing: 10) {
                    SettingsIcon(symbol: toggle.symbol, tint: toggle.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(toggle.title)
                        Text(toggle.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .toggleStyle(.switch)
            .disabled(!available)
            .opacity(available ? 1 : 0.5)

            if isOn, let missing {
                MissingPermissionNote(permission: missing) { model.grant(missing) }
                    .padding(.leading, 34)
            }
        }
    }
}

/// "Needs Full Disk Access — Grant…", under a switch that is on but cannot work.
struct MissingPermissionNote: View {
    let permission: SettingsPermission
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SettingsColor.orange)
            Text("Serve il permesso «\(permission.title)»")
                .font(.system(size: 11, weight: .medium))
            Spacer(minLength: 8)
            Button("Concedi…", action: action)
                .controlSize(.small)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(SettingsColor.orange.opacity(0.12)))
    }
}

/// How long the pointer rests on the notch before the island opens.
struct HoverDelayRow: View {
    let model: SettingsModel

    var body: some View {
        SliderRow(
            title: "Apertura al passaggio del puntatore",
            detail: "Quanto a lungo il puntatore deve restare sulla notch prima che l'isola si apra. Un valore più alto evita aperture involontarie quando vai verso la barra dei menu.",
            symbol: "cursorarrow.rays",
            tint: SettingsColor.indigo,
            value: Binding(get: { model.hoverDelay }, set: { model.setHoverDelay($0) }),
            range: 0...0.4,
            step: 0.01,
            valueText: "\(Int((model.hoverDelay * 1000).rounded())) ms",
            minimumLabel: "Subito",
            maximumLabel: "Con calma"
        )
    }
}

/// Which app runs the timers started from the notch: Halo's own, or the Clock app.
struct TimerAppRow: View {
    let model: SettingsModel

    var body: some View {
        let isAvailable = model.isOn(id: "systemTimers")
        HStack(alignment: .top, spacing: 10) {
            SettingsIcon(symbol: "timer", tint: SettingsColor.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("App dei timer della notch")
                Text("Con Orologio, i timer avviati dalla notch e dal menu finiscono anche nell'app Orologio: a ogni comando Orologio compare per un istante. Serve Accessibilità. Pomodoro e cronometro restano di Halo.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Picker("App dei timer della notch", selection: Binding(get: { model.timerApp }, set: { model.setTimerApp($0) })) {
                Text("Halo").tag(TimerApp.halo)
                Text("Orologio").tag(TimerApp.clock)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()
        }
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.5)
    }
}

/// Moves synced lyrics earlier or later.
struct LyricsLeadRow: View {
    let model: SettingsModel

    var body: some View {
        SliderRow(
            title: "Sincronia del testo",
            detail: "Se il testo arriva dopo la voce spostalo verso «Prima», se arriva troppo presto verso «Dopo». Con le cuffie Bluetooth di solito serve un po' più avanti.",
            symbol: "timer",
            tint: SettingsColor.pink,
            value: Binding(get: { model.lyricsLead }, set: { model.setLyricsLead($0) }),
            range: -1...1.5,
            step: 0.05,
            valueText: Self.text(for: model.lyricsLead),
            minimumLabel: "Dopo",
            maximumLabel: "Prima"
        )
        .disabled(!model.isOn(id: "lyrics"))
        .opacity(model.isOn(id: "lyrics") ? 1 : 0.5)
    }

    static func text(for lead: Double) -> String {
        let seconds = lead.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "it_IT")))
        if abs(lead) < 0.001 { return "in sincro" }
        return lead > 0 ? "\(seconds) s prima" : "\(seconds.replacingOccurrences(of: "-", with: "")) s dopo"
    }
}

struct SliderRow: View {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let step: Double
    let valueText: String
    let minimumLabel: String
    let maximumLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                SettingsIcon(symbol: symbol, tint: tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text(valueText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step) {
                EmptyView()
            } minimumValueLabel: {
                Text(minimumLabel).font(.system(size: 10)).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text(maximumLabel).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .padding(.leading, 34)
        }
    }
}

/// Every permission: what uses it, whether it is granted, and the way to grant it.
struct PermissionsSection: View {
    let model: SettingsModel

    var body: some View {
        Section {
            ForEach(SettingsPermission.allCases) { permission in
                PermissionRow(
                    permission: permission,
                    state: model.state(of: permission),
                    isNeeded: model.isNeeded(permission)
                ) {
                    model.grant(permission)
                }
            }
        } footer: {
            Text("Dopo aver concesso un permesso in Impostazioni di Sistema torna qui: lo stato si aggiorna da solo. Con una firma ad-hoc i permessi vanno ridati a ogni ricompilazione (vedi README, certificato «Halo Local»).")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

struct PermissionRow: View {
    let permission: SettingsPermission
    let state: PermissionState
    let isNeeded: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            SettingsIcon(symbol: permission.symbol, tint: permission.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title)
                Text(permission.usage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            status
        }
    }

    @ViewBuilder
    private var status: some View {
        switch state {
        case .granted:
            Label("Concesso", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SettingsColor.green)
        case .missing:
            VStack(alignment: .trailing, spacing: 4) {
                Button(isNeeded ? "Concedi…" : "Apri…", action: action)
                    .controlSize(.small)
                if isNeeded {
                    Text("Necessario")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SettingsColor.orange)
                }
            }
        case .notAsked:
            Text("Verrà chiesto al primo uso")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

/// Where things come from, and the diagnostics to send when something misbehaves.
struct AboutSection: View {
    var body: some View {
        DiagnosticsSection(diagnostics: Diagnostics.shared)
        Section("Come si usa") {
            Hint(symbol: "cursorarrow.motionlines", text: "Passa il puntatore sulla notch per aprire l'isola; allontanati per chiuderla.")
            Hint(symbol: "hand.draw", text: "Sull'isola aperta scorri a destra o a sinistra per cambiare brano, in su o in giù per il volume.")
            Hint(symbol: "tray.and.arrow.down", text: "Trascina file sulla notch per metterli sullo scaffale.")
            Hint(symbol: "menubar.rectangle", text: "Il menu di Halo nella barra dei menu ha timer, cronometro e queste impostazioni (⌘,).")
        }
        Section("Riconoscimenti") {
            Hint(symbol: "music.note", text: "Now Playing tramite mediaremote-adapter di Jonas van den Berg (licenza BSD a 3 clausole).")
            Hint(symbol: "quote.bubble", text: "Testi sincronizzati da LRCLIB.")
            Hint(symbol: "cloud.sun", text: "Meteo da Open-Meteo.")
        }
    }
}

/// The latest entries of `Diagnostics`, newest first, and the button that copies them all.
struct DiagnosticsSection: View {
    let diagnostics: Diagnostics

    var body: some View {
        Section {
            HStack {
                Text("Versione \(Diagnostics.build)")
                    .font(.system(size: 11).monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Spacer()
                Button("Copia diagnostica") {
                    diagnostics.copyReport()
                }
            }
            if diagnostics.entries.isEmpty {
                Text("Ancora niente: usa il player nella notch e torna qui.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(diagnostics.entries.suffix(14).reversed())) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(entry.date, format: .dateTime.hour().minute().second())
                                .foregroundStyle(.secondary)
                            Text(entry.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.system(size: 10.5).monospaced())
                    }
                }
                .textSelection(.enabled)
            }
        } header: {
            Text("Diagnostica")
        } footer: {
            Text("Se qualcosa non funziona (per esempio la pausa), riprova e poi premi «Copia diagnostica»: il testo copiato dice cosa è successo, passo per passo.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

struct Hint: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// White glyph on a rounded square of the feature's color, as in System Settings.
struct SettingsIcon: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous).fill(tint.gradient))
            .accessibilityHidden(true)
    }
}
