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

    @Test func aPauseFromHaloOutlivesTheLogsClear() {
        var state = SystemTimerState()
        _ = state.apply(.running(id: "A", end: now.addingTimeInterval(300)), now: now)
        state.pause(now: now.addingTimeInterval(100))
        #expect(state.current?.pausedRemaining == 200)

        _ = state.apply(.cleared, now: now.addingTimeInterval(100))
        #expect(state.current?.pausedRemaining == 200)
        #expect(state.current?.focusTimer == FocusTimer(mode: .countdown, duration: 300, endDate: nil, pausedRemaining: 200))

        let resumed = now.addingTimeInterval(160)
        _ = state.apply(.running(id: "A", end: resumed.addingTimeInterval(200)), now: resumed)
        #expect(state.current == SystemTimer(id: "A", end: resumed.addingTimeInterval(200), total: 300))
    }

    @Test func clearingForgetsAPausedTimer() {
        var state = SystemTimerState()
        _ = state.apply(.running(id: "A", end: now.addingTimeInterval(300)), now: now)
        state.pause(now: now)
        state.clear()
        #expect(state.current == nil)
    }

    @Test func becomesACountdown() {
        let timer = SystemTimer(id: "A", end: now.addingTimeInterval(60), total: 300)
        #expect(timer.focusTimer == FocusTimer(mode: .countdown, duration: 300, endDate: now.addingTimeInterval(60), pausedRemaining: nil))
    }
}
