import AppKit
import Observation

/// Countdown, Pomodoro and stopwatch. While one runs the island shows it as a live
/// activity in its wings; when a timer ends a sound plays and a banner says what comes
/// next.
///
/// One sleeping task waits for the timer's end: nothing ticks while timer or stopwatch
/// run (the views count from their dates on their own).
@MainActor
@Observable
final class TimerController {
    private(set) var timer: FocusTimer?
    private(set) var stopwatch: Stopwatch?
    private(set) var isEnabled = Preferences.timerEnabled

    /// Something to show as a live activity.
    var isActive: Bool {
        timer != nil || stopwatch != nil
    }

    @ObservationIgnored private let alerts: AlertCenter
    @ObservationIgnored private var endTask: Task<Void, Never>?

    /// Presets offered in the island and in the menu, in minutes.
    static let presets = [1, 5, 10, 15, 25]

    init(alerts: AlertCenter) {
        self.alerts = alerts
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.timerEnabled = enabled
        if !enabled {
            stop()
            resetStopwatch()
        }
    }

    // MARK: Stopwatch

    func startStopwatch() {
        stopwatch = .started(at: Date())
    }

    /// Pauses a running stopwatch, resumes a paused one, starts one otherwise.
    func toggleStopwatch() {
        let now = Date()
        guard let stopwatch else {
            startStopwatch()
            return
        }
        self.stopwatch = stopwatch.isRunning ? stopwatch.paused(at: now) : stopwatch.resumed(at: now)
    }

    func resetStopwatch() {
        stopwatch = nil
    }

    // MARK: Controls

    func start(minutes: Int) {
        run(.start(.countdown, duration: TimeInterval(minutes * 60), at: Date()))
    }

    func startPomodoro() {
        let mode = TimerMode.focus(round: 1)
        run(.start(mode, duration: Pomodoro.duration(of: mode) ?? Pomodoro.focus, at: Date()))
    }

    func togglePause() {
        guard let timer else { return }
        run(timer.isRunning ? timer.paused(at: Date()) : timer.resumed(at: Date()))
    }

    func addMinute() {
        guard let timer else { return }
        run(timer.adding(60, at: Date()))
    }

    func stop() {
        endTask?.cancel()
        endTask = nil
        timer = nil
        alerts.withdraw(.timer)
    }

    // MARK: Private

    private func run(_ timer: FocusTimer) {
        self.timer = timer
        endTask?.cancel()
        guard let end = timer.endDate else {
            endTask = nil
            return
        }
        let delay = max(0, end.timeIntervalSinceNow)
        endTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    private func finish() {
        guard let finished = timer else { return }
        NSSound(named: "Glass")?.play()

        if let next = Pomodoro.next(after: finished.mode), let duration = Pomodoro.duration(of: next) {
            run(.start(next, duration: duration, at: Date()))
            alerts.post(.timer(TimerAlert(finished: finished.mode, next: next)))
        } else {
            endTask = nil
            timer = nil
            alerts.post(.timer(TimerAlert(finished: finished.mode, next: nil)))
        }
    }
}
