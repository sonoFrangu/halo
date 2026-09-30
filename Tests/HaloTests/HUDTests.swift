import CoreGraphics
import Testing
@testable import Halo

struct HUDStepTests {
    private func isClose(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) < 1e-9
    }

    @Test func stepsOnTheSixteenthGrid() {
        #expect(isClose(HUDStep.next(from: 0.5, up: true, fine: false), 0.5625))
        #expect(isClose(HUDStep.next(from: 0.5, up: false, fine: false), 0.4375))
    }

    @Test func offGridLevelsSnapToTheNextStep() {
        let up = HUDStep.next(from: 0.53, up: true, fine: false)
        let down = HUDStep.next(from: 0.53, up: false, fine: false)
        #expect(isClose(up, 0.5625))
        #expect(isClose(down, 0.5))
    }

    /// Levels as the display reads them back after being set on the grid (Float rounding in
    /// corebrightnessd): 81.25 % reads 0.812500119, 87.5 % reads 0.874999881. They must still
    /// move a whole step, or the key does nothing.
    @Test func levelsReadBackWithFloatErrorStillMove() {
        #expect(isClose(HUDStep.next(from: 0.874999881, up: true, fine: false), 0.9375))
        #expect(isClose(HUDStep.next(from: 0.812500119, up: false, fine: false), 0.75))
        #expect(isClose(HUDStep.next(from: Double(Float(0.515625)) - 2e-7, up: true, fine: true), 0.53125))
    }

    @Test func fineStepsAreQuarterSteps() {
        #expect(isClose(HUDStep.next(from: 0.5, up: true, fine: true), 0.515625))
    }

    @Test func clampsAtTheEnds() {
        #expect(HUDStep.next(from: 1, up: true, fine: false) == 1)
        #expect(HUDStep.next(from: 0, up: false, fine: false) == 0)
        #expect(HUDStep.next(from: 1.4, up: true, fine: false) == 1)
        #expect(HUDStep.next(from: -0.2, up: false, fine: false) == 0)
    }

    @Test func sixteenPressesCoverTheRange() {
        var level = 0.0
        for _ in 0..<16 {
            level = HUDStep.next(from: level, up: true, fine: false)
        }
        #expect(isClose(level, 1))
    }
}

@MainActor
struct MediaKeyTests {
    @Test func mapsSystemKeyCodes() {
        #expect(MediaKeyTap.Key(code: 0) == .volumeUp)
        #expect(MediaKeyTap.Key(code: 1) == .volumeDown)
        #expect(MediaKeyTap.Key(code: 2) == .brightnessUp)
        #expect(MediaKeyTap.Key(code: 3) == .brightnessDown)
        #expect(MediaKeyTap.Key(code: 7) == .mute)
        #expect(MediaKeyTap.Key(code: 16) == nil)
    }
}

struct HUDLayoutTests {
    static let layouts = [
        IslandLayout(notchSize: CGSize(width: 190, height: 32), hasPhysicalNotch: true),
        IslandLayout(notchSize: CGSize(width: 184, height: 24), hasPhysicalNotch: false),
    ]

    @Test(arguments: HUDLayoutTests.layouts)
    func hudWingsAreWiderThanCompactOnesAtNotchHeight(layout: IslandLayout) {
        let hud = layout.spec(for: .alert, context: IslandContext(alertStyle: .wings))
        let compact = layout.spec(for: .compact, context: IslandContext(hasMedia: true))
        #expect(hud.width > compact.width)
        #expect(hud.height == layout.notchSize.height)
    }

    @Test(arguments: HUDLayoutTests.layouts)
    func hudContentSitsInTheWings(layout: IslandLayout) {
        let hud = layout.spec(for: .alert, context: IslandContext(alertStyle: .wings))
        let bodyMinX = layout.centerX - hud.width / 2
        let bodyMaxX = layout.centerX + hud.width / 2
        let notchMinX = layout.centerX - layout.notchSize.width / 2
        let notchMaxX = layout.centerX + layout.notchSize.width / 2

        #expect(layout.hudGlyphFrame.minX > bodyMinX)
        #expect(layout.hudGlyphFrame.maxX < notchMinX)
        #expect(layout.hudBarFrame.minX > notchMaxX)
        #expect(layout.hudBarFrame.width >= 30)
        #expect(layout.hudBarFrame.maxX < bodyMaxX)
    }
}
