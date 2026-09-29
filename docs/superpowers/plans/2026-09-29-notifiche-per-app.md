# Notifiche per app — piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Per ogni app scegliere se le sue notifiche compaiono nella notch (Mostra / Solo app / Non mostrare) e se passano anche durante una Full Immersione.

**Architecture:** Una funzione pura `NotificationRules.decide` prende la decisione per ogni notifica; le regole stanno in `Preferences`. `NotificationMirror` la applica notifica per notifica al posto dello scarto in blocco della Full Immersione. La pagina Avvisi delle Impostazioni elenca le app lette dalla tabella `app` del database di Centro Notifiche, filtrate alle app installate.

**Tech Stack:** Swift 6.2, SwiftUI + AppKit, SQLite3 (già usato), Swift Testing. Build: `swift build -c release`; app: `scripts/bundle.sh` → `build/Halo.app`.

Spec: `docs/superpowers/specs/2026-09-29-notifiche-per-app-design.md`.

## Global Constraints

- Niente macro SwiftUI (`@State`, `@Entry`, `#Preview`, `@Previewable`): non si espandono con i Command Line Tools.
- Su questo Mac non c'è Xcode: `swift test` non compila (manca il plugin `TestingMacros`). I test Swift Testing si scrivono comunque e girano in CI; in locale la logica pura si verifica con uno script `swiftc` nella scratchpad (vedi Task 1, Step 3) e il resto con `swift build -c release`.
- Commenti e messaggi di commit in inglese; testi dell'interfaccia in italiano.
- Stile: file piccoli, doc comment `///` che spiegano il perché.
- Commit alla fine di ogni task, solo in locale (niente push), con la riga `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task 1: Regole e preferenze

**Files:**
- Create: `Sources/Halo/Notifications/NotificationRules.swift`
- Modify: `Sources/Halo/App/Preferences.swift` (due chiavi e quattro funzioni)
- Test: `Tests/HaloTests/NotificationRulesTests.swift`

**Interfaces:**
- Produces:
  - `enum NotificationAppMode: String, CaseIterable, Sendable { case show, appOnly, hidden }`
  - `enum NotificationDecision: Equatable, Sendable { case drop, full, appOnly }`
  - `enum NotificationRules { nonisolated static func decide(bundleIdentifier: String, ownBundleIdentifier: String?, mode: NotificationAppMode, focusSilencing: Bool, bypassesFocus: Bool) -> NotificationDecision }`
  - `Preferences.notificationMode(for: String) -> NotificationAppMode`, `Preferences.setNotificationMode(_: NotificationAppMode, for: String)`, `Preferences.bypassesFocus(_: String) -> Bool`, `Preferences.setBypassesFocus(_: Bool, for: String)`

- [ ] **Step 1: Test**

`Tests/HaloTests/NotificationRulesTests.swift`:

```swift
import Testing
@testable import Halo

struct NotificationRulesTests {
    private func decide(
        _ bundleIdentifier: String = "net.whatsapp.WhatsApp",
        mode: NotificationAppMode = .show,
        focusSilencing: Bool = false,
        bypassesFocus: Bool = false
    ) -> NotificationDecision {
        NotificationRules.decide(
            bundleIdentifier: bundleIdentifier,
            ownBundleIdentifier: "io.github.sonofrangu.halo",
            mode: mode,
            focusSilencing: focusSilencing,
            bypassesFocus: bypassesFocus
        )
    }

    @Test func modesWithoutFocus() {
        #expect(decide(mode: .show) == .full)
        #expect(decide(mode: .appOnly) == .appOnly)
        #expect(decide(mode: .hidden) == .drop)
    }

    @Test func focusSilencesAppsThatDoNotBypassIt() {
        #expect(decide(mode: .show, focusSilencing: true) == .drop)
        #expect(decide(mode: .appOnly, focusSilencing: true) == .drop)
    }

    @Test func bypassPassesFocusButKeepsTheMode() {
        #expect(decide(mode: .show, focusSilencing: true, bypassesFocus: true) == .full)
        #expect(decide(mode: .appOnly, focusSilencing: true, bypassesFocus: true) == .appOnly)
        #expect(decide(mode: .hidden, focusSilencing: true, bypassesFocus: true) == .drop)
    }

    @Test func websitesAndHaloAreNeverShown() {
        #expect(decide("_WEB_CENTER_:web.com.example", bypassesFocus: true) == .drop)
        #expect(decide("io.github.sonofrangu.halo") == .drop)
    }
}
```

- [ ] **Step 2: Regole**

`Sources/Halo/Notifications/NotificationRules.swift`:

```swift
import Foundation

/// How an app's notifications appear in the notch, chosen per app in Settings › Avvisi.
enum NotificationAppMode: String, CaseIterable, Sendable {
    /// The whole banner: sender, message and photo.
    case show
    /// Only the app's icon and name, for apps whose content should not show on screen.
    case appOnly
    /// Not in the notch at all (the system banner still appears).
    case hidden
}

enum NotificationDecision: Equatable, Sendable {
    case drop
    case full
    case appOnly
}

/// Whether one notification reaches the notch, and how.
enum NotificationRules {
    nonisolated static func decide(
        bundleIdentifier: String,
        ownBundleIdentifier: String?,
        mode: NotificationAppMode,
        focusSilencing: Bool,
        bypassesFocus: Bool
    ) -> NotificationDecision {
        if bundleIdentifier == ownBundleIdentifier || NotificationMirror.isFromWebsite(bundleIdentifier) {
            return .drop
        }
        if mode == .hidden || (focusSilencing && !bypassesFocus) {
            return .drop
        }
        return mode == .appOnly ? .appOnly : .full
    }
}
```

- [ ] **Step 3: Verifica locale della logica**

Senza Xcode, compila le regole con uno stub di `NotificationMirror.isFromWebsite` e le stesse asserzioni del test:

```bash
S=/private/tmp/claude-501/-Users-matteo-halo/ab91a8e2-3fda-4034-97e0-7658a887d100/scratchpad
cat > $S/stub.swift <<'EOF'
enum NotificationMirror {
    nonisolated static func isFromWebsite(_ id: String) -> Bool { id.hasPrefix("_WEB_CENTER_") }
}
EOF
cat > $S/main.swift <<'EOF'
func d(_ id: String = "a", _ m: NotificationAppMode = .show, _ f: Bool = false, _ b: Bool = false) -> NotificationDecision {
    NotificationRules.decide(bundleIdentifier: id, ownBundleIdentifier: "halo", mode: m, focusSilencing: f, bypassesFocus: b)
}
assert(d() == .full && d("a", .appOnly) == .appOnly && d("a", .hidden) == .drop)
assert(d("a", .show, true) == .drop && d("a", .appOnly, true) == .drop)
assert(d("a", .show, true, true) == .full && d("a", .appOnly, true, true) == .appOnly && d("a", .hidden, true, true) == .drop)
assert(d("_WEB_CENTER_:web.x", .show, false, true) == .drop && d("halo") == .drop)
print("ok")
EOF
xcrun swiftc -o $S/rules Sources/Halo/Notifications/NotificationRules.swift $S/stub.swift $S/main.swift && $S/rules
```

Expected: `ok`.

- [ ] **Step 4: Preferenze**

In `Preferences.swift`, dentro `enum Key` dopo `notificationsFollowFocus`:

```swift
        static let notificationAppModes = "notificationAppModes"
        static let notificationFocusBypass = "notificationFocusBypass"
```

Dopo `notificationsFollowFocus`:

```swift
    /// How an app's notifications show in the notch. Only non-default modes are stored,
    /// so apps never seen before show their notifications.
    static func notificationMode(for bundleIdentifier: String) -> NotificationAppMode {
        (defaults.dictionary(forKey: Key.notificationAppModes)?[bundleIdentifier] as? String)
            .flatMap(NotificationAppMode.init(rawValue:)) ?? .show
    }

    static func setNotificationMode(_ mode: NotificationAppMode, for bundleIdentifier: String) {
        var modes = defaults.dictionary(forKey: Key.notificationAppModes) ?? [:]
        modes[bundleIdentifier] = mode == .show ? nil : mode.rawValue
        defaults.set(modes, forKey: Key.notificationAppModes)
    }

    /// Apps whose notifications still show while a Focus silences the others.
    static func bypassesFocus(_ bundleIdentifier: String) -> Bool {
        defaults.stringArray(forKey: Key.notificationFocusBypass)?.contains(bundleIdentifier) ?? false
    }

    static func setBypassesFocus(_ bypasses: Bool, for bundleIdentifier: String) {
        var identifiers = Set(defaults.stringArray(forKey: Key.notificationFocusBypass) ?? [])
        if bypasses {
            identifiers.insert(bundleIdentifier)
        } else {
            identifiers.remove(bundleIdentifier)
        }
        defaults.set(identifiers.sorted(), forKey: Key.notificationFocusBypass)
    }
```

- [ ] **Step 5: Build**

Run: `swift build -c release 2>&1 | grep -E "error|Compiling|Build complete" | tail -5`
Expected: `Build complete!`, nessun `error`.

- [ ] **Step 6: Commit**

```bash
git add Sources/Halo/Notifications/NotificationRules.swift Sources/Halo/App/Preferences.swift Tests/HaloTests/NotificationRulesTests.swift
git commit -m "feat(notifications): per-app notification rules and preferences

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Applicare le regole e leggere l'elenco delle app

**Files:**
- Modify: `Sources/Halo/Notifications/NotificationDatabase.swift` (nuova query `appIdentifiers()`)
- Modify: `Sources/Halo/Notifications/NotificationMirror.swift` (`isSuppressed` → `isFocusSilencing`, decisione per notifica, `appIdentifiers()`)
- Modify: `Sources/Halo/App/AppDelegate.swift:28-30`

**Interfaces:**
- Consumes: `NotificationRules.decide`, `NotificationDecision`, `Preferences.notificationMode(for:)`, `Preferences.bypassesFocus(_:)` (Task 1).
- Produces: `NotificationMirror.appIdentifiers() -> [String]` (vuoto se il mirroring non è attivo o la query fallisce); `NotificationMirror.isFocusSilencing: () -> Bool`.

- [ ] **Step 1: Query delle app**

In `NotificationDatabase.swift`, dopo `records(after:limit:)`:

```swift
    /// Every app registered with Notification Center (system services included).
    func appIdentifiers() throws(OpenError) -> [String] {
        var identifiers: [String] = []
        try query("SELECT identifier FROM app", row: { statement in
            guard let identifier = sqlite3_column_text(statement, 0) else { return }
            identifiers.append(String(cString: identifier))
        })
        return identifiers
    }
```

- [ ] **Step 2: Decisione per notifica nel mirror**

In `NotificationMirror.swift` sostituisci la proprietà `isSuppressed` e il suo commento con:

```swift
    /// Whether a Focus is silencing notifications now; apps allowed through still show.
    @ObservationIgnored var isFocusSilencing: () -> Bool = { false }
```

In `databaseChanged()` sostituisci da `guard !isSuppressed() else { return }` fino alla fine del ciclo `for` con:

```swift
        let focusSilencing = isFocusSilencing()
        let shown = records.count > Self.burstLimit ? [newest] : records
        for record in shown {
            let decision = NotificationRules.decide(
                bundleIdentifier: record.bundleIdentifier,
                ownBundleIdentifier: Bundle.main.bundleIdentifier,
                mode: Preferences.notificationMode(for: record.bundleIdentifier),
                focusSilencing: focusSilencing,
                bypassesFocus: Preferences.bypassesFocus(record.bundleIdentifier)
            )
            guard let alert = Self.alert(for: record, decision: decision) else { continue }
            guard let imageURL = alert.imageURL else {
                alerts.post(.notification(alert))
                continue
            }
            // The banner reads the thumbnail synchronously, so it is made before posting.
            Task { [weak self] in
                _ = await NotificationThumbnail.load(alert.id, from: imageURL)
                self?.alerts.post(.notification(alert))
            }
        }
```

Sostituisci `alert(for:)` con:

```swift
    private static func alert(for record: NotificationRecord, decision: NotificationDecision) -> NotificationAlert? {
        let appName = AppName.of(record.bundleIdentifier)
        switch decision {
        case .drop:
            return nil
        case .appOnly:
            // No title or body: the banner shows the app's name only, and no photo.
            return NotificationAlert(
                id: record.id,
                bundleIdentifier: record.bundleIdentifier,
                text: NotificationText.make(title: nil, subtitle: nil, body: nil, appName: appName),
                imageURL: nil
            )
        case .full:
            let payload = NotificationPayload.parse(record.data) ?? NotificationPayload()
            return NotificationAlert(
                id: record.id,
                bundleIdentifier: record.bundleIdentifier,
                text: NotificationText.make(
                    title: payload.title,
                    subtitle: payload.subtitle,
                    body: payload.body,
                    appName: appName
                ),
                imageURL: payload.imageURL
            )
        }
    }
```

Dopo `refreshAccess()` aggiungi:

```swift
    /// Installed apps that can send notifications, for the per-app list in Settings.
    /// Empty while mirroring is off or Full Disk Access is missing.
    func appIdentifiers() -> [String] {
        guard let database else { return [] }
        do {
            return try database.appIdentifiers()
        } catch {
            Log.app.error("notification apps read failed: \(String(describing: error), privacy: .public)")
            return []
        }
    }
```

- [ ] **Step 3: AppDelegate**

`Sources/Halo/App/AppDelegate.swift:28-30` diventa:

```swift
        notifications.isFocusSilencing = { [weak focus] in
            Preferences.notificationsFollowFocus && focus?.active != nil
        }
```

- [ ] **Step 4: Build e controllo riferimenti**

Run: `grep -rn "isSuppressed" Sources/ Tests/; swift build -c release 2>&1 | grep -E "error|Build complete" | tail -5`
Expected: nessun `isSuppressed`; `Build complete!`.

- [ ] **Step 5: Commit**

```bash
git add Sources/Halo/Notifications/NotificationDatabase.swift Sources/Halo/Notifications/NotificationMirror.swift Sources/Halo/App/AppDelegate.swift
git commit -m "feat(notifications): apply per-app rules to each mirrored notification

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Elenco nelle Impostazioni e README

**Files:**
- Modify: `Sources/Halo/Settings/SettingsModel.swift` (kind nuovo, gruppo nella pagina Avvisi, stato dell'elenco)
- Modify: `Sources/Halo/UI/Settings/SettingsView.swift` (caso in `SettingsItemRow`, `NotificationAppsRow`)
- Modify: `README.md` (riga Notifiche della tabella e paragrafo Notifiche)

**Interfaces:**
- Consumes: `NotificationMirror.appIdentifiers()` (Task 2), `Preferences.notificationMode/setNotificationMode/bypassesFocus/setBypassesFocus` (Task 1), `AppName.of`.
- Produces: `SettingsItem.Kind.notificationApps`, `struct NotificationAppEntry: Identifiable { let id: String; let name: String; let icon: NSImage }`, `SettingsModel.notificationApps`, `SettingsModel.notificationMode(for:)`, `setNotificationMode(_:for:)`, `bypassesFocus(_:)`, `setBypassesFocus(_:for:)`.

- [ ] **Step 1: Modello**

In `SettingsModel.swift`, in `SettingsItem.Kind` aggiungi `case notificationApps` e sotto `timerApp`:

```swift
    static let notificationApps = SettingsItem(id: "notificationApps", kind: .notificationApps)
```

Prima di `struct SettingsGroup` aggiungi:

```swift
/// An app in the per-app notification list.
struct NotificationAppEntry: Identifiable {
    let id: String
    let name: String
    let icon: NSImage
}
```

(Se `SettingsModel.swift` non importa `AppKit`, aggiungi `import AppKit` in cima.)

In `SettingsModel`, dopo `private(set) var revision = 0`:

```swift
    /// Installed apps registered with Notification Center, by name; read on refresh.
    private(set) var notificationApps: [NotificationAppEntry] = []
```

Dopo `setTimerApp(_:)`:

```swift
    func notificationMode(for bundleIdentifier: String) -> NotificationAppMode {
        _ = revision
        return Preferences.notificationMode(for: bundleIdentifier)
    }

    func setNotificationMode(_ mode: NotificationAppMode, for bundleIdentifier: String) {
        Preferences.setNotificationMode(mode, for: bundleIdentifier)
        revision += 1
    }

    func bypassesFocus(_ bundleIdentifier: String) -> Bool {
        _ = revision
        return Preferences.bypassesFocus(bundleIdentifier)
    }

    func setBypassesFocus(_ bypasses: Bool, for bundleIdentifier: String) {
        Preferences.setBypassesFocus(bypasses, for: bundleIdentifier)
        revision += 1
    }

    /// Only identifiers of installed apps: the table also lists system services.
    private func loadNotificationApps() {
        let own = Bundle.main.bundleIdentifier
        notificationApps = features.notifications.appIdentifiers()
            .filter { $0 != own && !NotificationMirror.isFromWebsite($0) }
            .compactMap { identifier in
                guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else { return nil }
                return NotificationAppEntry(id: identifier, name: AppName.of(identifier), icon: NSWorkspace.shared.icon(forFile: url.path))
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
```

In `refresh()`, dopo `features.focus.refreshAccess()`, aggiungi `loadNotificationApps()`. In `init`, dopo `togglesByID = toggles`, aggiungi `loadNotificationApps()`.

Nella pagina Avvisi (`let alerts = [...]`), subito dopo il gruppo `id: "notifications"`:

```swift
            SettingsGroup(
                id: "notificationApps",
                title: "Notifiche per app",
                footer: "Solo app: nella notch compaiono icona e nome, senza il testo. La luna fa passare l'app anche mentre una Full Immersione silenzia le notifiche.",
                items: [.notificationApps]
            ),
```

- [ ] **Step 2: Vista**

In `SettingsView.swift`, in `SettingsItemRow.body` aggiungi:

```swift
        case .notificationApps:
            NotificationAppsRow(model: model)
```

In fondo al file:

```swift
/// Every app that can send notifications: how its notifications show in the notch and
/// whether they pass a Focus.
struct NotificationAppsRow: View {
    let model: SettingsModel

    var body: some View {
        let isAvailable = model.isOn(id: "notifications")
        let showsFocus = model.isOn(id: "notificationsFollowFocus")
        VStack(alignment: .leading, spacing: 10) {
            if model.state(of: .fullDiskAccess) == .missing {
                MissingPermissionNote(permission: .fullDiskAccess) { model.grant(.fullDiskAccess) }
            } else if model.notificationApps.isEmpty {
                Text("Nessuna app ha ancora mandato notifiche.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            ForEach(model.notificationApps) { app in
                HStack(spacing: 10) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .frame(width: 22, height: 22)
                    Text(app.name)
                    Spacer(minLength: 8)
                    if showsFocus {
                        Toggle(isOn: Binding(
                            get: { model.bypassesFocus(app.id) },
                            set: { model.setBypassesFocus($0, for: app.id) }
                        )) {
                            Image(systemName: "moon.fill")
                        }
                        .toggleStyle(.button)
                        .help("Anche con Full Immersione")
                    }
                    Picker(app.name, selection: Binding(
                        get: { model.notificationMode(for: app.id) },
                        set: { model.setNotificationMode($0, for: app.id) }
                    )) {
                        Text("Mostra").tag(NotificationAppMode.show)
                        Text("Solo app").tag(NotificationAppMode.appOnly)
                        Text("Non mostrare").tag(NotificationAppMode.hidden)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            }
        }
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.5)
    }
}
```

- [ ] **Step 3: README**

Nella tabella Funzioni, riga **Notifiche**, colonna Note: `stile Dynamic Island con miniatura delle foto; clic = apre l'app; niente notifiche dei siti; per ogni app: mostra, solo nome, nascondi, passa la Full Immersione`.

Nel paragrafo "Ricarica, AirPods, notifiche", dopo il punto **Notifiche**, aggiungi:

```markdown
- **Notifiche per app** (Impostazioni › Avvisi): ogni app installata che può mandare notifiche
  ha un menu *Mostra* / *Solo app* (icona e nome, senza testo né foto) / *Non mostrare*; con
  "Silenzia durante una Full Immersione" acceso, la luna accanto fa passare quell'app anche
  durante una Full Immersione. Le app nuove partono da *Mostra*.
```

- [ ] **Step 4: Build, bundle, prova a mano**

Run: `swift build -c release 2>&1 | grep -E "error|Build complete" | tail -5`, poi esci da Halo (`osascript -e 'quit app id "io.github.sonofrangu.halo"'`), `scripts/bundle.sh`, `open build/Halo.app`.

Verifica a mano:
1. Impostazioni › Avvisi: il gruppo "Notifiche per app" elenca app vere con icona, in ordine alfabetico, senza servizi di sistema.
2. Una app su *Non mostrare*: una sua notifica non compare nella notch.
3. Una app su *Solo app*: compare solo il nome, senza testo né foto.
4. Con "Silenzia durante una Full Immersione" spento la luna sparisce.

- [ ] **Step 5: Commit**

```bash
git add Sources/Halo/Settings/SettingsModel.swift Sources/Halo/UI/Settings/SettingsView.swift README.md
git commit -m "feat(settings): per-app notification list in Avvisi

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
