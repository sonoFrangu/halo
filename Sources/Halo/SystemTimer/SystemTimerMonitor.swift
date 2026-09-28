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
