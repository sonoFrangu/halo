import Foundation
import Testing
@testable import Halo

struct StopwatchTests {
    private let start = Date(timeIntervalSince1970: 10_000)

    @Test func countsPausesAndResumes() {
        let running = Stopwatch.started(at: start)
        #expect(running.isRunning)
        #expect(running.elapsed(at: start.addingTimeInterval(42)) == 42)

        let paused = running.paused(at: start.addingTimeInterval(42))
        #expect(!paused.isRunning)
        #expect(paused.elapsed(at: start.addingTimeInterval(500)) == 42)

        let resumed = paused.resumed(at: start.addingTimeInterval(500))
        #expect(resumed.elapsed(at: start.addingTimeInterval(510)) == 52)
        #expect(resumed.startDate == start.addingTimeInterval(458))
    }

    @Test func pausingTwiceOrResumingARunningOneChangesNothing() {
        let running = Stopwatch.started(at: start)
        #expect(running.resumed(at: start.addingTimeInterval(5)) == running)
        let paused = running.paused(at: start.addingTimeInterval(5))
        #expect(paused.paused(at: start.addingTimeInterval(9)) == paused)
    }
}

struct FocusStoreTests {
    private func json(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    private func record(_ identifier: String, startingAt start: Double) -> [String: Any] {
        [
            "assertionDetails": ["assertionDetailsModeIdentifier": identifier],
            "assertionStartDateTimestamp": start,
        ]
    }

    private func store(_ entry: [String: Any]) throws -> Data {
        let root: [String: Any] = ["data": [entry]]
        return try json(root)
    }

    @Test func readsTheLatestFocusTurnedOnByHand() throws {
        let records = [record("com.apple.focus.work", startingAt: 100), record("com.apple.focus.reading", startingAt: 200)]
        let assertions = try store(["storeAssertionRecords": records])
        #expect(FocusStore.activeIdentifier(assertions: assertions) == "com.apple.focus.reading")
    }

    @Test func noRecordsMeansNoFocus() throws {
        let noRecords: [[String: Any]] = []
        #expect(FocusStore.activeIdentifier(assertions: try store(["storeAssertionRecords": noRecords])) == nil)
        #expect(FocusStore.activeIdentifier(assertions: try store([:])) == nil)
        #expect(FocusStore.activeIdentifier(assertions: Data("garbage".utf8)) == nil)
    }

    @Test func describesConfiguredFocuses() throws {
        let defaultMode: [String: Any] = ["mode": ["name": "Do Not Disturb", "symbolImageName": "moon.fill"]]
        let customMode: [String: Any] = [
            "mode": ["name": "Studio", "symbolImageName": "music.note", "tintColorName": "systemPinkColor"],
        ]
        let modesByID: [String: Any] = [
            "com.apple.donotdisturb.mode.default": defaultMode,
            "com.example.custom": customMode,
        ]
        let configurations = try store(["modeConfigurations": modesByID])
        let modes = FocusStore.modes(configurations: configurations)
        #expect(modes["com.apple.donotdisturb.mode.default"]?.name == "Non disturbare")
        let custom = try #require(modes["com.example.custom"])
        #expect(custom.name == "Studio")
        #expect(custom.symbol == "music.note")
        #expect(custom.tint == FocusStore.color(named: "systemPinkColor"))
    }

    @Test func fallsBackForUnknownFocuses() {
        let work = FocusStore.mode(identifier: "com.apple.focus.work")
        #expect(work.name == "Lavoro")
        #expect(work.symbol == "briefcase.fill")
        let unknown = FocusStore.mode(identifier: "com.example.nameless")
        #expect(unknown.name == "Full Immersione")
        #expect(unknown.symbol == "moon.fill")
    }
}

struct TransferTests {
    @Test func stripsPartialDownloadSuffixes() {
        #expect(TransferNaming.displayName(for: URL(fileURLWithPath: "/d/Report.pdf.download")) == "Report.pdf")
        #expect(TransferNaming.displayName(for: URL(fileURLWithPath: "/d/movie.mp4.crdownload")) == "movie.mp4")
        #expect(TransferNaming.displayName(for: URL(fileURLWithPath: "/d/photo.HEIC")) == "photo.HEIC")
        #expect(TransferNaming.isPartial(URL(fileURLWithPath: "/d/a.zip.part")))
        #expect(!TransferNaming.isPartial(URL(fileURLWithPath: "/d/a.zip")))
    }

    @Test func gateLetsThroughWholePercentsAndTheEnd() {
        let gate = FractionGate()
        #expect(gate.admit(0))
        #expect(!gate.admit(0.004))
        #expect(gate.admit(0.012))
        #expect(!gate.admit(0.015))
        #expect(gate.admit(0.5))
        #expect(gate.admit(0.995))
        #expect(gate.admit(1))
        #expect(!gate.admit(1))
    }
}
