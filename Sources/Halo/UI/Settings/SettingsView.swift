import SwiftUI

/// The Settings window: every feature switch grouped like System Settings, the hover
/// delay, and shortcuts to the permissions a feature is missing.
struct SettingsView: View {
    let model: SettingsModel

    var body: some View {
        Form {
            SettingsHeader()

            if model.needsAccessibility || model.needsFullDiskAccess || model.calendarDenied {
                Section("Permessi da concedere") {
                    if model.needsAccessibility {
                        PermissionRow(
                            title: "Accessibilità",
                            detail: "Per l'HUD di luminosità e volume e per Bloc Maiusc",
                            symbol: "accessibility",
                            action: model.requestAccessibility
                        )
                    }
                    if model.needsFullDiskAccess {
                        PermissionRow(
                            title: "Accesso completo al disco",
                            detail: "Per mostrare le notifiche nella notch",
                            symbol: "externaldrive.fill",
                            action: model.openFullDiskAccess
                        )
                    }
                    if model.calendarDenied {
                        PermissionRow(
                            title: "Calendario",
                            detail: "Per i prossimi impegni e i promemoria",
                            symbol: "calendar",
                            action: model.openCalendarPrivacy
                        )
                    }
                }
            }

            ForEach(model.sections) { section in
                Section(section.title) {
                    ForEach(section.toggles) { toggle in
                        SettingsToggleRow(model: model, toggle: toggle)
                    }
                    if section.id == "island" {
                        HoverDelayRow(model: model)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 680)
    }
}

/// App name and version above the switches.
struct SettingsHeader: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black)
                Capsule()
                    .fill(Color.white)
                    .frame(width: 30, height: 10)
                    .offset(y: -10)
            }
            .frame(width: 52, height: 52)
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Halo")
                    .font(.system(size: 20, weight: .semibold))
                Text("La tua notch, più viva. Versione \(Self.version)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }
}

/// A feature switch with a System Settings-style colored icon.
struct SettingsToggleRow: View {
    let model: SettingsModel
    let toggle: SettingsToggle

    var body: some View {
        Toggle(isOn: Binding(get: { model.isOn(toggle) }, set: { model.set(toggle, $0) })) {
            HStack(spacing: 10) {
                SettingsIcon(symbol: toggle.symbol, tint: toggle.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(toggle.title)
                    if let detail = toggle.detail {
                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .toggleStyle(.switch)
    }
}

/// How long the pointer rests on the notch before the island opens.
struct HoverDelayRow: View {
    let model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                SettingsIcon(symbol: "cursorarrow.rays", tint: Color(red: 0.35, green: 0.34, blue: 0.84))
                Text("Apertura al passaggio del puntatore")
                Spacer()
                Text("\(Int((model.hoverDelay * 1000).rounded())) ms")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { model.hoverDelay }, set: { model.setHoverDelay($0) }), in: 0...0.4, step: 0.01) {
                EmptyView()
            } minimumValueLabel: {
                Text("Subito").font(.system(size: 10)).foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("Con calma").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }
}

/// A permission a feature is missing, with the button that fixes it.
struct PermissionRow: View {
    let title: String
    let detail: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            SettingsIcon(symbol: symbol, tint: Color(red: 1, green: 0.58, blue: 0))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Concedi…", action: action)
        }
    }
}

/// White glyph on a rounded square of the feature's color.
struct SettingsIcon: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tint.gradient))
            .accessibilityHidden(true)
    }
}
