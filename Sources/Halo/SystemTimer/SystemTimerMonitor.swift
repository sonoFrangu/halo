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
    @ObservationIgnored private let clock = ClockAppDriver()
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

    // MARK: Controls (through the Clock app)

    /// Whether the timers started from the notch go to the Clock app.
    var startsInClock: Bool {
        isEnabled && Preferences.timerApp == .clock
    }

    /// Starts a Clock timer; `false` when Clock could not be driven.
    func startInClock(minutes: Int) async -> Bool {
        await clock.start(minutes: minutes)
    }

    /// Pauses at once on screen (the log would only say the timer is gone), or resumes
    /// (the log then reports the new end). Undone if Clock could not be driven.
    func togglePause() {
        guard let timer = current else { return }
        let before = state
        if timer.pausedRemaining == nil {
            state.pause(now: Date())
            current = state.current
        }
        Task {
            if await !clock.togglePause() {
                state = before
                current = state.current
            }
        }
    }

    func cancel() {
        guard current != nil else { return }
        let before = state
        state.clear()
        current = nil
        Task {
            if await !clock.cancel() {
                state = before
                current = state.current
            }
        }
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

/// Which app runs the timers started from the notch and the menu.
enum TimerApp: String {
    case clock
    case halo
}

/// Timer commands from the notch and the menu: a new countdown goes to the Clock app when
/// chosen (Halo's own timer if Clock cannot be driven); pause and stop act on the timer
/// shown, Halo's first.
@MainActor
enum TimerCommands {
    static func start(minutes: Int, timers: TimerController, systemTimers: SystemTimerMonitor) {
        guard systemTimers.startsInClock else {
            timers.start(minutes: minutes)
            return
        }
        Task {
            if await !systemTimers.startInClock(minutes: minutes) {
                timers.start(minutes: minutes)
            }
        }
    }

    static func togglePause(timers: TimerController, systemTimers: SystemTimerMonitor) {
        if timers.timer != nil {
            timers.togglePause()
        } else {
            systemTimers.togglePause()
        }
    }

    static func stop(timers: TimerController, systemTimers: SystemTimerMonitor) {
        if timers.timer != nil {
            timers.stop()
        } else {
            systemTimers.cancel()
        }
    }

    /// The countdown to show and control: Halo's, or the Clock one.
    static func shown(timers: TimerController, systemTimers: SystemTimerMonitor) -> FocusTimer? {
        timers.timer ?? systemTimers.current?.focusTimer
    }
}
