import Testing
@testable import Halo

struct ScrollGestureInterpreterTests {
    /// A trackpad swipe as AppKit reports it with natural scrolling on: deltas follow the
    /// content, which moves with the fingers.
    private func swipe(
        fingersX: Double = 0,
        fingersY: Double = 0,
        steps: Int = 10,
        inverted: Bool = true
    ) -> [ScrollSample] {
        let stepX = fingersX / Double(steps)
        let stepY = fingersY / Double(steps)
        // Natural: deltaX = finger x, deltaY = -finger y. Classic: both negated.
        let deltaX = inverted ? stepX : -stepX
        let deltaY = inverted ? -stepY : stepY
        var samples = [ScrollSample(deltaX: 0, deltaY: 0, phase: .began, isMomentum: false, isPrecise: true, isInverted: inverted)]
        for _ in 0..<steps {
            samples.append(ScrollSample(deltaX: deltaX, deltaY: deltaY, phase: .changed, isMomentum: false, isPrecise: true, isInverted: inverted))
        }
        samples.append(ScrollSample(deltaX: 0, deltaY: 0, phase: .ended, isMomentum: false, isPrecise: true, isInverted: inverted))
        return samples
    }

    private func actions(_ samples: [ScrollSample], allowsTrackSkip: Bool = true, swipeUpDismisses: Bool = false) -> [ScrollGestureInterpreter.Action] {
        var interpreter = ScrollGestureInterpreter()
        return samples.compactMap { interpreter.handle($0, allowsTrackSkip: allowsTrackSkip, swipeUpDismisses: swipeUpDismisses) }
    }

    @Test(arguments: [true, false])
    func swipingUpOverAnAlertDismissesItOnce(inverted: Bool) {
        #expect(actions(swipe(fingersY: 120, inverted: inverted), allowsTrackSkip: false, swipeUpDismisses: true) == [.dismiss])
        #expect(actions(swipe(fingersY: -120, inverted: inverted), allowsTrackSkip: false, swipeUpDismisses: true).isEmpty)
        #expect(actions(swipe(fingersY: 20, inverted: inverted), allowsTrackSkip: false, swipeUpDismisses: true).isEmpty)
    }

    @Test(arguments: [true, false])
    func swipingLeftSkipsForwardOnce(inverted: Bool) {
        #expect(actions(swipe(fingersX: -200, inverted: inverted)) == [.nextTrack])
    }

    @Test(arguments: [true, false])
    func swipingRightGoesBack(inverted: Bool) {
        #expect(actions(swipe(fingersX: 120, inverted: inverted)) == [.previousTrack])
    }

    @Test func shortSwipesDoNothing() {
        #expect(actions(swipe(fingersX: -40)).isEmpty)
    }

    @Test func trackSkipsCanBeDisabled() {
        #expect(actions(swipe(fingersX: -200), allowsTrackSkip: false).isEmpty)
    }

    @Test(arguments: [true, false])
    func swipingUpRaisesTheVolume(inverted: Bool) {
        let result = actions(swipe(fingersY: 110, inverted: inverted))
        let total = result.reduce(0.0) { sum, action in
            if case .volume(let delta) = action { return sum + delta }
            Issue.record("unexpected \(action)")
            return sum
        }
        // The first few points only lock the axis.
        #expect(total > 0.4 && total < 0.51)
    }

    @Test func aDiagonalSwipeLocksToItsMainAxis() {
        let result = actions(swipe(fingersX: -200, fingersY: 60))
        #expect(result == [.nextTrack])
    }

    @Test func momentumIsIgnored() {
        var interpreter = ScrollGestureInterpreter()
        let momentum = ScrollSample(deltaX: -30, deltaY: 0, phase: .none, isMomentum: true, isPrecise: true, isInverted: true)
        #expect(interpreter.handle(momentum, allowsTrackSkip: true) == nil)
    }

    @Test func mouseWheelNotchesStepTheVolume() {
        var interpreter = ScrollGestureInterpreter()
        let up = ScrollSample(deltaX: 0, deltaY: 1, phase: .none, isMomentum: false, isPrecise: false, isInverted: false)
        let down = ScrollSample(deltaX: 0, deltaY: -3, phase: .none, isMomentum: false, isPrecise: false, isInverted: false)
        #expect(interpreter.handle(up, allowsTrackSkip: true) == .volume(ScrollGestureInterpreter.volumePerLine))
        #expect(interpreter.handle(down, allowsTrackSkip: true) == .volume(-ScrollGestureInterpreter.volumePerLine))
    }

    @Test func eachSwipeSkipsAtMostOnce() {
        let twoSwipes = swipe(fingersX: -200) + swipe(fingersX: -200)
        #expect(actions(twoSwipes) == [.nextTrack, .nextTrack])
    }
}
