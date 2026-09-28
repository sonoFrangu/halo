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
