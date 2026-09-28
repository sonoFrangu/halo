# Siri e timer di sistema nella notch — piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** La notch si illumina mentre Siri è a schermo e mostra come attività live i timer avviati con Siri o con l'app Orologio.

**Architecture:** Due monitor indipendenti, sul modello di quelli esistenti (`UnlockGreeter`, `TransferMonitor`). `SystemTimerMonitor` legge `log stream` (messaggi timer del Centro di Controllo) e pubblica il timer come `FocusTimer`, riusando `LiveActivity.timer`. `SiriMonitor` usa un `AXObserver` sui due processi di Siri più la lista finestre, e tiene su un avviso `.siri` tramite `AlertCenter.setInteracting`.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, ApplicationServices (AX), CoreGraphics (window list), Foundation `Process`, swift-testing. Build con Command Line Tools (`swift build`, `swift test`, `scripts/bundle.sh`).

**Spec:** `docs/superpowers/specs/2026-09-28-siri-e-timer-di-sistema-design.md`

## Global Constraints

- Build con Command Line Tools: niente `@State` (macro senza plugin), come nel resto del progetto.
- Swift 6 strict concurrency: niente `static let` di tipi non `Sendable` (es. `DateFormatter`); callback C sul main thread con box `@unchecked Sendable` + `MainActor.assumeIsolated` (modello: `MediaKeyTap.swift`).
- Testi dell'interfaccia e diagnostiche in italiano; commenti e commit in inglese.
- Nessuna nuova dipendenza.
- Entrambe le funzioni attive di default (`siriEnabled`, `systemTimersEnabled`).
- Comandi: senza Xcode, `swift test` va lanciato con `-Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing` (qui sotto abbreviato in `swift test`); `--filter <Suite>` per una suite; `scripts/bundle.sh` per l'app.

## File

| File | Responsabilità |
|---|---|
| Create `Sources/Halo/SystemTimer/SystemTimerLogParser.swift` | `SystemTimerEvent` + parser puro del messaggio di log |
| Create `Sources/Halo/SystemTimer/SystemTimerState.swift` | `SystemTimer` + `SystemTimerState` (riduttore puro degli eventi) |
| Create `Sources/Halo/SystemTimer/SystemTimerMonitor.swift` | processo `log stream`, stato osservabile, avviso alla fine |
| Create `Sources/Halo/System/SiriMonitor.swift` | rileva Siri a schermo, tiene l'avviso `.siri` |
| Create `Sources/Halo/UI/Alerts/SiriViews.swift` | `SiriGlowView` (bordo) e `SiriGlyph` (ala sinistra) |
| Create `Tests/HaloTests/SystemTimerTests.swift` | test di parser e riduttore |
| Modify `Sources/Halo/App/Preferences.swift` | due chiavi + accessor |
| Modify `Sources/Halo/Alerts/IslandAlert.swift` | caso `.siri` |
| Modify `Sources/Halo/Island/IslandServices.swift` | `systemTimers`, `.siri` in `activate` |
| Modify `Sources/Halo/UI/PlayerActions.swift` | `IslandModels.systemTimers` |
| Modify `Sources/Halo/Island/IslandController.swift` | passa `systemTimers`, osserva l'attività con `LiveActivity.current` |
| Modify `Sources/Halo/UI/Timer/CompactTimerView.swift` | `LiveActivity.current` include il timer di sistema |
| Modify `Sources/Halo/UI/IslandContentView.swift` | nuova firma di `LiveActivity.current`, `SiriGlyph` |
| Modify `Sources/Halo/UI/IslandRootView.swift` | `SiriGlowView` sopra il contenuto |
| Modify `Sources/Halo/App/AppDelegate.swift` | crea, avvia, ferma i monitor; `Features` |
| Modify `Sources/Halo/Settings/SettingsModel.swift` | due interruttori |
| Modify `docs/design.md` | sezioni Siri e timer di sistema |

---

### Task 1: Parser dei messaggi timer

**Files:**
- Create: `Sources/Halo/SystemTimer/SystemTimerLogParser.swift`
- Test: `Tests/HaloTests/SystemTimerTests.swift`

**Interfaces:**
- Produces: `enum SystemTimerEvent: Sendable, Equatable { case running(id: String, end: Date); case cleared; case fired(id: String) }`, `enum SystemTimerLogParser { static func event(from message: String) -> SystemTimerEvent? }`

- [ ] **Step 1: Scrivi i test (falliscono)**

```swift
import Foundation
import Testing
@testable import Halo

/// Messages copied from Control Center's log on macOS 26 (subsystem
/// com.apple.mobiletimer.logging), with the narrow no-break space macOS puts before "PM".
struct SystemTimerLogParserTests {
    @Test func readsTheEndOfARunningTimer() {
        let message = "E0F1C9D6-CA93-44AD-B98A-132C4275EB8D has next trigger <MTTrigger: 0x76b2a454e0; trigger: Alert; date: \"Monday, September 28, 2026 at 5:45:28\u{202F}PM Central European Summer Time\">"
        #expect(SystemTimerLogParser.event(from: message) == .running(
            id: "E0F1C9D6-CA93-44AD-B98A-132C4275EB8D",
            end: Date(timeIntervalSince1970: 1_790_610_328)
        ))
    }

    @Test func readsClearedAndFired() {
        #expect(SystemTimerLogParser.event(from: "<MTTimerManager: 0x76b0d36000> notified next timer changed: (null)") == .cleared)
        #expect(SystemTimerLogParser.event(from: "<MTTimerManager: 0x76b0d36000> notified timer fired: 89F7A589-BCC5-43E5-940C-ADB369DC17D9") == .fired(id: "89F7A589-BCC5-43E5-940C-ADB369DC17D9"))
    }

    @Test func ignoresEverythingElse() {
        #expect(SystemTimerLogParser.event(from: "<MTTimerManager: 0x76b0d36000> notified next timer changed: F8789CE6-0A10-4C56-880F-78CAF57BA0F0") == nil)
        #expect(SystemTimerLogParser.event(from: "<MTTimerManager: 0x76b0d36000> notified timers update: (") == nil)
        #expect(SystemTimerLogParser.event(from: "X has next trigger <MTTrigger: 0x1; trigger: Alert; date: \"not a date\">") == nil)
    }
}
```

- [ ] **Step 2: Verifica che falliscano**

Run: `swift test --filter SystemTimerLogParserTests`
Expected: errore di compilazione, `SystemTimerLogParser` non esiste.

- [ ] **Step 3: Implementa**

```swift
import Foundation

/// A Clock timer event (timers started with Siri or the Clock app).
///
/// Read from Control Center's log messages: `mobiletimerd` accepts only Apple's own
/// clients, and the menu bar timer is not exposed to Accessibility. A pause and a
/// cancellation log the same messages, so both are `.cleared`.
enum SystemTimerEvent: Sendable, Equatable {
    /// The soonest timer runs and ends at `end` (started or resumed).
    case running(id: String, end: Date)
    /// No timer is running any more: paused, cancelled or done.
    case cleared
    case fired(id: String)
}

enum SystemTimerLogParser {
    /// The event a message stands for, or `nil` for everything else.
    static func event(from message: String) -> SystemTimerEvent? {
        if message.hasSuffix("notified next timer changed: (null)") {
            return .cleared
        }
        if let fired = message.range(of: "notified timer fired: ") {
            return .fired(id: message[fired.upperBound...].trimmingCharacters(in: .whitespaces))
        }
        guard
            let trigger = message.range(of: " has next trigger "),
            let open = message.range(of: "date: \"", range: trigger.upperBound..<message.endIndex),
            let close = message.range(of: "\"", range: open.upperBound..<message.endIndex),
            let end = date(from: String(message[open.upperBound..<close.lowerBound]))
        else {
            return nil
        }
        return .running(id: String(message[..<trigger.lowerBound]), end: end)
    }

    /// "Monday, September 28, 2026 at 5:45:28 PM Central European Summer Time". A
    /// formatter per call: events are rare, and `DateFormatter` is not `Sendable`.
    static func date(from text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm:ss a zzzz"
        let plain = text
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
        return formatter.date(from: plain)
    }
}
```

- [ ] **Step 4: Verifica che passino**

Run: `swift test --filter SystemTimerLogParserTests`
Expected: 3 test passati. Se `readsTheEndOfARunningTimer` fallisce perché `zzzz` non legge "Central European Summer Time", taglia il testo al fuso (tutto dopo `AM`/`PM`), usa il formato senza `zzzz` e `formatter.timeZone = .current`, e nel test confronta con la data costruita nello stesso fuso tramite `Calendar.current`.

- [ ] **Step 5: Commit**

```bash
git add Sources/Halo/SystemTimer/SystemTimerLogParser.swift Tests/HaloTests/SystemTimerTests.swift
git commit -m "feat(timers): parse Clock timer events from Control Center's log"
```

---

### Task 2: Stato del timer di sistema

**Files:**
- Create: `Sources/Halo/SystemTimer/SystemTimerState.swift`
- Test: `Tests/HaloTests/SystemTimerTests.swift` (aggiungi la suite)

**Interfaces:**
- Consumes: `SystemTimerEvent` (Task 1)
- Produces: `struct SystemTimer: Sendable, Equatable { id: String; end: Date; total: TimeInterval; var focusTimer: FocusTimer }`, `struct SystemTimerState { private(set) var current: SystemTimer?; mutating func apply(_ event: SystemTimerEvent, now: Date) -> Bool }` (ritorna `true` quando il timer è appena suonato)

- [ ] **Step 1: Scrivi i test (falliscono)** — aggiungi in fondo a `Tests/HaloTests/SystemTimerTests.swift`:

```swift
struct SystemTimerStateTests {
    private let now = Date(timeIntervalSince1970: 50_000)

    @Test func keepsTheLengthAcrossAPause() {
        var state = SystemTimerState()
        let started = state.apply(.running(id: "A", end: now.addingTimeInterval(300)), now: now)
        #expect(!started)
        #expect(state.current == SystemTimer(id: "A", end: now.addingTimeInterval(300), total: 300))

        let paused = state.apply(.cleared, now: now.addingTimeInterval(7))
        #expect(!paused)
        #expect(state.current == nil)

        let resumed = now.addingTimeInterval(15)
        _ = state.apply(.running(id: "A", end: resumed.addingTimeInterval(293)), now: resumed)
        #expect(state.current?.total == 300)
    }

    @Test func aNewTimerStartsItsOwnLength() {
        var state = SystemTimerState()
        _ = state.apply(.running(id: "A", end: now.addingTimeInterval(300)), now: now)
        _ = state.apply(.running(id: "B", end: now.addingTimeInterval(60)), now: now)
        #expect(state.current == SystemTimer(id: "B", end: now.addingTimeInterval(60), total: 60))
    }

    @Test func firingClearsAndReports() {
        var state = SystemTimerState()
        _ = state.apply(.running(id: "A", end: now.addingTimeInterval(60)), now: now)
        let fired = state.apply(.fired(id: "A"), now: now.addingTimeInterval(60))
        #expect(fired)
        #expect(state.current == nil)
    }

    @Test func ignoresAnEndAlreadyPast() {
        var state = SystemTimerState()
        _ = state.apply(.running(id: "A", end: now.addingTimeInterval(-1)), now: now)
        #expect(state.current == nil)
    }

    @Test func becomesACountdown() {
        let timer = SystemTimer(id: "A", end: now.addingTimeInterval(60), total: 300)
        #expect(timer.focusTimer == FocusTimer(mode: .countdown, duration: 300, endDate: now.addingTimeInterval(60), pausedRemaining: nil))
    }
}
```

- [ ] **Step 2: Verifica che falliscano**

Run: `swift test --filter SystemTimerStateTests`
Expected: errore di compilazione, `SystemTimerState` non esiste.

- [ ] **Step 3: Implementa**

```swift
import Foundation

/// A Clock timer as the island shows it.
struct SystemTimer: Sendable, Equatable {
    var id: String
    var end: Date
    /// Length when first seen running, kept across pauses so the ring shows real progress.
    var total: TimeInterval

    /// Shown exactly like Halo's own countdown.
    var focusTimer: FocusTimer {
        FocusTimer(mode: .countdown, duration: total, endDate: end, pausedRemaining: nil)
    }
}

/// Folds the log's events into the timer to show.
struct SystemTimerState {
    private(set) var current: SystemTimer?
    /// Lengths of the timers seen so far, by id: a resumed timer keeps its own.
    private var totals: [String: TimeInterval] = [:]

    /// Applies an event; returns `true` when a timer just fired.
    mutating func apply(_ event: SystemTimerEvent, now: Date) -> Bool {
        switch event {
        case .running(let id, let end):
            guard end > now else { return false }
            let total = totals[id] ?? end.timeIntervalSince(now)
            totals[id] = total
            current = SystemTimer(id: id, end: end, total: total)
            return false
        case .cleared:
            current = nil
            return false
        case .fired(let id):
            totals[id] = nil
            current = nil
            return true
        }
    }
}
```

- [ ] **Step 4: Verifica che passino**

Run: `swift test --filter SystemTimer`
Expected: 8 test passati (3 + 5).

- [ ] **Step 5: Commit**

```bash
git add Sources/Halo/SystemTimer/SystemTimerState.swift Tests/HaloTests/SystemTimerTests.swift
git commit -m "feat(timers): fold Clock timer events into the timer to show"
```

---

### Task 3: Monitor dei timer di sistema, nella notch e nelle Impostazioni

**Files:**
- Create: `Sources/Halo/SystemTimer/SystemTimerMonitor.swift`
- Modify: `Sources/Halo/App/Preferences.swift`, `Sources/Halo/Island/IslandServices.swift`, `Sources/Halo/UI/PlayerActions.swift`, `Sources/Halo/Island/IslandController.swift`, `Sources/Halo/UI/Timer/CompactTimerView.swift`, `Sources/Halo/UI/IslandContentView.swift`, `Sources/Halo/App/AppDelegate.swift`, `Sources/Halo/Settings/SettingsModel.swift`

**Interfaces:**
- Consumes: `SystemTimerLogParser.event(from:)`, `SystemTimerState`, `SystemTimer.focusTimer`, `LineSplitter` (esistente), `AlertCenter.post(_:)`, `TimerAlert(finished:next:)`
- Produces: `@MainActor @Observable final class SystemTimerMonitor { init(alerts: AlertCenter); private(set) var current: SystemTimer?; private(set) var isEnabled: Bool; func start(); func stop(); func setEnabled(_:) }`, `Preferences.systemTimersEnabled`, `Preferences.siriEnabled`, `LiveActivity.current(timers:systemTimers:transfers:)`

- [ ] **Step 1: Preferenze** — in `Preferences.swift`, dentro `enum Key` accanto a `unlockAnimation`:

```swift
        static let systemTimers = "systemTimersEnabled"
        static let siri = "siriEnabled"
```

e accanto a `unlockAnimationEnabled`:

```swift
    /// Timers started with Siri or the Clock app, as a live activity.
    static var systemTimersEnabled: Bool {
        get { flag(Key.systemTimers, default: true) }
        set { defaults.set(newValue, forKey: Key.systemTimers) }
    }

    /// The island glows while Siri is on screen.
    static var siriEnabled: Bool {
        get { flag(Key.siri, default: true) }
        set { defaults.set(newValue, forKey: Key.siri) }
    }
```

- [ ] **Step 2: Il monitor** — `Sources/Halo/SystemTimer/SystemTimerMonitor.swift`:

```swift
import Foundation
import Observation

/// Follows the timers started with Siri or the Clock app through Control Center's log
/// (see `SystemTimerEvent` for why the log), shows the running one as a live activity and
/// posts the timer banner when it fires. `log stream` is event driven: it wakes Halo only
/// when Control Center logs a timer message.
@MainActor
@Observable
final class SystemTimerMonitor {
    private(set) var current: SystemTimer?
    private(set) var isEnabled = Preferences.systemTimersEnabled

    @ObservationIgnored private let alerts: AlertCenter
    @ObservationIgnored private var state = SystemTimerState()
    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var consumer: Task<Void, Never>?
    @ObservationIgnored private var restartTask: Task<Void, Never>?
    /// Consecutive exits of `log` without a single event in between.
    @ObservationIgnored private var failures = 0

    static let maximumFailures = 3
    static let arguments = [
        "stream", "--style", "ndjson", "--level", "default",
        "--predicate", "process == \"ControlCenter\" AND subsystem == \"com.apple.mobiletimer.logging\"",
    ]

    init(alerts: AlertCenter) {
        self.alerts = alerts
    }

    func start() {
        guard isEnabled, process == nil else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = Self.arguments
        process.standardInput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let stdout = Pipe()
        process.standardOutput = stdout

        let (chunks, continuation) = AsyncStream.makeStream(of: Data.self)
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                continuation.finish()
            } else {
                continuation.yield(data)
            }
        }

        do {
            try process.run()
        } catch {
            Diagnostics.shared.record("timer di Orologio: log non avviato (\(error.localizedDescription))")
            return
        }
        self.process = process
        consumer = Task.detached(priority: .utility) { [weak self] in
            var splitter = LineSplitter()
            for await chunk in chunks {
                for line in splitter.append(chunk) {
                    if let event = Self.event(fromLine: line) {
                        await self?.apply(event)
                    }
                }
            }
            if !Task.isCancelled {
                await self?.streamEnded()
            }
        }
    }

    func stop() {
        restartTask?.cancel()
        restartTask = nil
        consumer?.cancel()
        consumer = nil
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        current = nil
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.systemTimersEnabled = enabled
        failures = 0
        if enabled { start() } else { stop() }
    }

    /// One `ndjson` line: the message is in `eventMessage`. Other lines (the header `log`
    /// prints first) are skipped.
    nonisolated static func event(fromLine line: Data) -> SystemTimerEvent? {
        struct Entry: Decodable {
            let eventMessage: String
        }
        guard let entry = try? JSONDecoder().decode(Entry.self, from: line) else { return nil }
        return SystemTimerLogParser.event(from: entry.eventMessage)
    }

    private func apply(_ event: SystemTimerEvent) {
        failures = 0
        let fired = state.apply(event, now: Date())
        current = state.current
        if fired {
            alerts.post(.timer(TimerAlert(finished: .countdown, next: nil)))
        }
    }

    /// `log` exited on its own: try again a few times, then give up and say so.
    private func streamEnded() {
        process = nil
        consumer = nil
        current = nil
        guard isEnabled else { return }
        failures += 1
        guard failures < Self.maximumFailures else {
            Diagnostics.shared.record("timer di Orologio: log stream si è chiuso \(failures) volte, smetto")
            return
        }
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.start()
        }
    }
}
```

- [ ] **Step 3: L'attività live** — in `Sources/Halo/UI/Timer/CompactTimerView.swift` sostituisci `LiveActivity.current` (e il suo commento):

```swift
/// What the compact island shows besides music, most important first: Halo's timer, the
/// stopwatch, a Clock timer (started with Siri or the Clock app), then a download or
/// AirDrop.
enum LiveActivity: Equatable {
    case timer(FocusTimer)
    case stopwatch(Stopwatch)
    case transfer(Transfer)

    @MainActor
    static func current(timers: TimerController, systemTimers: SystemTimerMonitor, transfers: TransferMonitor) -> LiveActivity? {
        if let timer = timers.timer { return .timer(timer) }
        if let stopwatch = timers.stopwatch { return .stopwatch(stopwatch) }
        if let system = systemTimers.current { return .timer(system.focusTimer) }
        if let transfer = transfers.current { return .transfer(transfer) }
        return nil
    }
}
```

- [ ] **Step 4: Servizi, modelli, isola**

`Sources/Halo/Island/IslandServices.swift`: dopo `let timers: TimerController` aggiungi `let systemTimers: SystemTimerMonitor`.

`Sources/Halo/UI/PlayerActions.swift`, in `IslandModels`: dopo `let timers: TimerController` aggiungi `let systemTimers: SystemTimerMonitor`.

`Sources/Halo/Island/IslandController.swift`, dove costruisce `IslandModels(`: dopo `timers: services.timers,` aggiungi `systemTimers: services.systemTimers,`. Poi sostituisci `observeLiveActivities()`:

```swift
    /// A timer, the stopwatch, a Clock timer or a download turns the compact island into a
    /// live activity.
    private func observeLiveActivities() {
        let timers = services.timers
        let systemTimers = services.systemTimers
        let transfers = services.transfers
        let active = withObservationTracking {
            LiveActivity.current(timers: timers, systemTimers: systemTimers, transfers: transfers) != nil
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeLiveActivities()
            }
        }
        viewModel.liveActivityChanged(active: active)
    }
```

`Sources/Halo/UI/IslandContentView.swift` riga 20:

```swift
        let activity = LiveActivity.current(timers: timers, systemTimers: models.systemTimers, transfers: models.transfers)
```

- [ ] **Step 5: AppDelegate** — in `applicationDidFinishLaunching`, dopo `let timers = TimerController(alerts: alerts)`:

```swift
        let systemTimers = SystemTimerMonitor(alerts: alerts)
```

In `IslandServices(` dopo `timers: timers,` aggiungi `systemTimers: systemTimers,`. In `Features(` dopo `timers: timers,` aggiungi `systemTimers: systemTimers,`. Nella struct `Features` dopo `let timers: TimerController` aggiungi `let systemTimers: SystemTimerMonitor`. Dopo `transfers.start()` aggiungi `systemTimers.start()`; in `applicationWillTerminate` dopo `features.transfers.stop()` aggiungi `features.systemTimers.stop()`.

- [ ] **Step 6: Impostazioni** — in `SettingsModel.catalog(for:)` dopo `let timers = f.timers` aggiungi `let systemTimers = f.systemTimers`; nel gruppo `live` di `activities`, subito dopo l'interruttore `id: "timer"`:

```swift
                    .toggle(SettingsToggle(
                        id: "systemTimers", title: "Timer di Siri e Orologio",
                        detail: "I timer avviati con Siri o con l'app Orologio compaiono nelle ali mentre corrono, e un avviso quando suonano. Un timer in pausa non compare.",
                        symbol: "clock.fill", tint: SettingsColor.orange,
                        isOn: { systemTimers.isEnabled },
                        setOn: { systemTimers.setEnabled($0) }
                    )),
```

- [ ] **Step 7: Compila e testa**

Run: `swift build 2>&1 | tail -5 && swift test 2>&1 | tail -2`
Expected: build senza errori; tutti i test passano (126 + 8).

- [ ] **Step 8: Prova sul Mac**

Run: `scripts/bundle.sh && (pkill -x Halo; sleep 1; open build/Halo.app)`
Poi chiedi all'utente: "Ehi Siri, timer di 2 minuti". Expected: anello e conto alla rovescia nelle ali; in pausa sparisce, alla ripresa ricompare con l'anello al punto giusto; allo scadere compare il banner "Tempo scaduto". Controlla anche `pgrep -fl "log stream"`: un solo processo, figlio di Halo. Uscendo da Halo dal menu (`NSApp.terminate`, che chiama `stop()`) il processo deve sparire. Con `pkill` resta orfano, come già succede all'adapter Now Playing: prima di ogni prova chiudi gli orfani con `pkill -f "log stream --style ndjson"`.

- [ ] **Step 9: Commit**

```bash
git add Sources/Halo/SystemTimer/SystemTimerMonitor.swift Sources/Halo/App/Preferences.swift Sources/Halo/Island/IslandServices.swift Sources/Halo/UI/PlayerActions.swift Sources/Halo/Island/IslandController.swift Sources/Halo/UI/Timer/CompactTimerView.swift Sources/Halo/UI/IslandContentView.swift Sources/Halo/App/AppDelegate.swift Sources/Halo/Settings/SettingsModel.swift
git commit -m "feat(timers): show timers started with Siri or Clock as a live activity"
```

---

### Task 4: Siri nella notch

**Files:**
- Create: `Sources/Halo/System/SiriMonitor.swift`, `Sources/Halo/UI/Alerts/SiriViews.swift`
- Modify: `Sources/Halo/Alerts/IslandAlert.swift`, `Sources/Halo/Island/IslandServices.swift`, `Sources/Halo/UI/IslandContentView.swift`, `Sources/Halo/UI/IslandRootView.swift`, `Sources/Halo/App/AppDelegate.swift`, `Sources/Halo/Settings/SettingsModel.swift`

**Interfaces:**
- Consumes: `Preferences.siriEnabled` (Task 3), `AlertCenter.post(_:)`, `.setInteracting(_:by:)`, `.withdraw(_:)`, `IslandLayout.hudGlyphFrame`, `NotchShape`, `\.reducesEffects`
- Produces: `IslandAlert.siri` / `IslandAlert.Kind.siri`, `@MainActor final class SiriMonitor { init(alerts: AlertCenter); private(set) var isEnabled: Bool; func start(); func stop(); func setEnabled(_:) }`, `struct SiriGlowView: View { let shape: NotchShape }`, `struct SiriGlyph: View { let isActive: Bool }`

- [ ] **Step 1: L'avviso** — in `Sources/Halo/Alerts/IslandAlert.swift`:
  - dopo `case unlock` (con il suo commento): `/// Siri is on screen; held up by \`SiriMonitor\` until it closes.` e `case siri`;
  - in `enum Kind` dopo `case unlock`: `case siri`;
  - in `kind`: `case .siri: .siri`;
  - in `style`: aggiungi `.siri` alla lista `.wings` → `case .hud, .power, .keyboard, .focus, .unlock, .siri: .wings`;
  - in `waitsOutPresentations`: `case .hud, .calendar, .timer, .keyboard, .focus, .unlock, .siri: false`;
  - in `duration`: `case .siri: .seconds(1)` (conta solo dopo che `SiriMonitor` lo rilascia, e lo ritira subito).

In `Sources/Halo/Island/IslandServices.swift`, `activate(_:)`: `case .hud, .power, .audioDevice, .timer, .keyboard, .focus, .unlock, .siri:`.

- [ ] **Step 2: Le viste** — `Sources/Halo/UI/Alerts/SiriViews.swift`:

```swift
import SwiftUI

/// The Apple Intelligence edge glow along the island's outline while Siri is on screen.
/// It turns slowly; with Reduce Motion or reduced effects it holds still.
struct SiriGlowView: View {
    let shape: NotchShape

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.reducesEffects) private var reducesEffects

    static let colors: [Color] = [
        Color(red: 0.98, green: 0.38, blue: 0.69),
        Color(red: 0.62, green: 0.4, blue: 1),
        Color(red: 0.29, green: 0.6, blue: 1),
        Color(red: 0.36, green: 0.9, blue: 0.9),
        Color(red: 1, green: 0.62, blue: 0.3),
        Color(red: 0.98, green: 0.38, blue: 0.69),
    ]
    /// Seconds per turn.
    static let period: Double = 4

    var body: some View {
        let still = reduceMotion || reducesEffects
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: still)) { context in
            let turn = still ? 0 : (context.date.timeIntervalSinceReferenceDate / Self.period).truncatingRemainder(dividingBy: 1)
            let gradient = AngularGradient(colors: Self.colors, center: .center, angle: .degrees(turn * 360))
            ZStack {
                shape.stroke(gradient, lineWidth: 8).blur(radius: 7)
                shape.stroke(gradient, lineWidth: 1.5)
            }
            .clipShape(shape)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Left wing while Siri is on screen: a waveform in Siri's colors.
struct SiriGlyph: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "waveform")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(LinearGradient(colors: SiriGlowView.colors, startPoint: .leading, endPoint: .trailing))
            .symbolEffect(.variableColor.iterative, isActive: isActive && !reduceMotion)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Siri")
    }
}
```

In `Sources/Halo/UI/IslandContentView.swift`, subito dopo il blocco `UnlockGlyph(...)` (tre righe):

```swift
            SiriGlyph(isActive: isAlert && kind == .siri)
                .place(in: layout.hudGlyphFrame)
                .reveal(isAlert && kind == .siri, order: 0)
```

In `Sources/Halo/UI/IslandRootView.swift`, dopo `IslandContentView(...).clipShape(shape)`:

```swift
            if island.state == .alert && island.alert?.kind == .siri {
                SiriGlowView(shape: shape)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
```

- [ ] **Step 3: Il monitor** — `Sources/Halo/System/SiriMonitor.swift`:

```swift
import AppKit
import ApplicationServices

/// Notices Siri on screen so the island can glow while it listens and answers.
///
/// Siri's windows belong to two processes, Siri.app and "Siri AI" (`com.apple.campo`). An
/// Accessibility observer wakes the monitor when either opens a window or changes focus;
/// the window list (owner PIDs need no permission) then says whether one is on screen.
/// While Siri is visible the list is checked twice a second, since a window closing is not
/// reliably notified. Without Accessibility the list is checked once a second.
@MainActor
final class SiriMonitor {
    private(set) var isEnabled = Preferences.siriEnabled
    private var isVisible = false
    private let alerts: AlertCenter
    private var observers: [pid_t: AXObserver] = [:]
    private var launchObserver: NSObjectProtocol?
    private var pollTask: Task<Void, Never>?

    static let bundleIdentifiers: Set<String> = ["com.apple.Siri", "com.apple.campo"]
    private static let holder = "siri"

    init(alerts: AlertCenter) {
        self.alerts = alerts
    }

    func start() {
        guard isEnabled, launchObserver == nil else { return }
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.attach()
            }
        }
        attach()
        check()
    }

    func stop() {
        if let launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(launchObserver)
        }
        launchObserver = nil
        for observer in observers.values {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observers.removeAll()
        pollTask?.cancel()
        pollTask = nil
        setVisible(false)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.siriEnabled = enabled
        if enabled { start() } else { stop() }
    }

    /// Looks again at the window list and schedules the next look when one is needed.
    fileprivate func check() {
        let visible = Self.isOnScreen(pids: Set(observers.keys).union(Self.siriPIDs()))
        setVisible(visible)
        pollTask?.cancel()
        let interval: Duration?
        if visible {
            interval = .milliseconds(500)
        } else if observers.isEmpty {
            // ponytail: polling without Accessibility; event driven once it is granted.
            interval = .seconds(1)
        } else {
            interval = nil
        }
        guard let interval else { return }
        pollTask = Task { [weak self] in
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled else { return }
            self?.check()
        }
    }

    private func attach() {
        guard AXIsProcessTrusted() else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for pid in Self.siriPIDs() where observers[pid] == nil {
            var created: AXObserver?
            guard AXObserverCreate(pid, siriObserverCallback, &created) == .success, let observer = created else { continue }
            let app = AXUIElementCreateApplication(pid)
            for name in [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification, kAXUIElementDestroyedNotification] {
                AXObserverAddNotification(observer, app, name as CFString, refcon)
            }
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
            observers[pid] = observer
        }
    }

    private func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        if visible {
            alerts.post(.siri)
            alerts.setInteracting(true, by: Self.holder)
        } else {
            alerts.setInteracting(false, by: Self.holder)
            alerts.withdraw(.siri)
        }
    }

    private static func siriPIDs() -> [pid_t] {
        NSWorkspace.shared.runningApplications
            .filter { bundleIdentifiers.contains($0.bundleIdentifier ?? "") }
            .map(\.processIdentifier)
    }

    private static func isOnScreen(pids: Set<pid_t>) -> Bool {
        guard
            !pids.isEmpty,
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else {
            return false
        }
        return windows.contains { window in
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t, pids.contains(pid) else { return false }
            return (window[kCGWindowAlpha as String] as? Double ?? 1) > 0
        }
    }
}

/// What the C callback hands to the main actor. `@unchecked Sendable`: the observers'
/// run loop sources are on the main run loop, so the callback runs on the main thread.
private struct SiriObserverContext: @unchecked Sendable {
    let monitor: UnsafeMutableRawPointer
}

/// C callback of the Accessibility observers (always on the main thread, see above).
private func siriObserverCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let context = SiriObserverContext(monitor: refcon)
    MainActor.assumeIsolated {
        Unmanaged<SiriMonitor>.fromOpaque(context.monitor).takeUnretainedValue().check()
    }
}
```

- [ ] **Step 4: AppDelegate e Impostazioni**

`AppDelegate.applicationDidFinishLaunching`: in `Features(` dopo `unlock: UnlockGreeter(alerts: alerts),` aggiungi `siri: SiriMonitor(alerts: alerts),`; nella struct `Features` dopo `let unlock: UnlockGreeter` aggiungi `let siri: SiriMonitor`; dopo `features.unlock.start()` aggiungi `features.siri.start()`; in `applicationWillTerminate` dopo `features.unlock.stop()` aggiungi `features.siri.stop()`.

`SettingsModel.catalog(for:)`: dopo `let unlock = f.unlock` aggiungi `let siri = f.siri`; nel gruppo `system` di `alerts`, dopo l'interruttore `id: "unlock"`:

```swift
                .toggle(SettingsToggle(
                    id: "siri", title: "Siri nella notch",
                    detail: "Mentre Siri ascolta e risponde la notch si illumina con i suoi colori. Il pannello di Siri resta dov'è.",
                    symbol: "waveform", tint: SettingsColor.indigo,
                    isOn: { siri.isEnabled },
                    setOn: { siri.setEnabled($0) }
                )),
```

- [ ] **Step 5: Compila e testa**

Run: `swift build 2>&1 | tail -5 && swift test 2>&1 | tail -2`
Expected: build senza errori (gli `switch` su `IslandAlert` sono esaustivi: se il compilatore ne segnala altri, aggiungi `.siri` accanto a `.unlock`); tutti i test passano.

- [ ] **Step 6: Prova sul Mac**

Run: `scripts/bundle.sh && (pkill -x Halo; sleep 1; open build/Halo.app)`
Chiedi all'utente di attivare Siri e fare una domanda. Expected: bordo colorato che ruota e onda nell'ala sinistra finché il pannello di Siri è aperto; entro ~0,5 s dalla chiusura tutto sparisce. Se non compare nulla, controlla `/usr/bin/log show --last 2m --predicate 'subsystem == "io.github.sonofrangu.halo"'` e verifica se `check()` viene chiamato all'apertura di Siri (aggiungi temporaneamente `Diagnostics.shared.record("siri check")`): se l'osservatore non si attiva, in `check()` usa `interval = .seconds(1)` anche quando `observers` non è vuoto (il ripiego della specifica) e aggiorna il commento `ponytail:`.

- [ ] **Step 7: Commit**

```bash
git add Sources/Halo/System/SiriMonitor.swift Sources/Halo/UI/Alerts/SiriViews.swift Sources/Halo/Alerts/IslandAlert.swift Sources/Halo/Island/IslandServices.swift Sources/Halo/UI/IslandContentView.swift Sources/Halo/UI/IslandRootView.swift Sources/Halo/App/AppDelegate.swift Sources/Halo/Settings/SettingsModel.swift
git commit -m "feat(siri): the island glows while Siri is on screen"
```

---

### Task 5: Documentazione

**Files:**
- Modify: `docs/design.md`

- [ ] **Step 1:** In `docs/design.md`, sezione "Attività live": nella prima frase l'ordine diventa "timer, cronometro, timer di Orologio, trasferimento"; aggiungi il punto:

```markdown
- **Timer di Siri e Orologio** (`SystemTimerMonitor`, `SystemTimerLogParser` e
  `SystemTimerState` testati): `mobiletimerd` accetta solo client Apple e la voce Timer della
  barra dei menu non è esposta all'Accessibilità, quindi Halo segue `log stream --style ndjson`
  sui messaggi `com.apple.mobiletimer.logging` del Centro di Controllo: "has next trigger"
  (corre, fino a una data), "next timer changed: (null)" (pausa, annullamento o fine: nel log
  sono uguali) e "timer fired" (banner timer). Il timer diventa un `FocusTimer` `.countdown`,
  con la durata vista al primo avvio; un timer in pausa non compare. Se `log` si chiude,
  riprova dopo 5 s, al terzo fallimento lo scrive nelle diagnostiche.
```

Dopo la sezione "Attività live" aggiungi:

```markdown
## Siri

`SiriMonitor`: un `AXObserver` sui processi `com.apple.Siri` e `com.apple.campo` ("Siri AI")
sveglia il monitor quando aprono una finestra; la lista finestre (i PID dei proprietari non
richiedono permessi) dice se una è a schermo, e finché lo è viene ricontrollata ogni 0,5 s.
Senza Accessibilità, controllo ogni secondo. Siri a schermo → avviso `.siri` (ali), tenuto con
`AlertCenter.setInteracting(by: "siri")` e ritirato alla chiusura. `SiriGlowView` disegna un
gradiente angolare che ruota lungo il bordo dell'isola (fermo con Riduci movimento o effetti
ridotti); `SiriGlyph` un'onda nell'ala sinistra. Il pannello di Siri resta dove lo mette macOS.
```

- [ ] **Step 2: Commit**

```bash
git add docs/design.md
git commit -m "docs: Siri and Clock timers in the notch"
```
