import Testing
@testable import Halo

struct UpdateCheckerTests {
    @Test func comparesVersionsNumerically() {
        #expect(UpdateChecker.isNewer("v0.4.5", than: "0.4.4"))
        #expect(UpdateChecker.isNewer("v0.4.10", than: "0.4.9"))
        #expect(UpdateChecker.isNewer("v1.0.0", than: "0.9.9"))
        #expect(!UpdateChecker.isNewer("v0.4.4", than: "0.4.4"))
        #expect(!UpdateChecker.isNewer("v0.4.3", than: "0.4.4"))
    }
}
