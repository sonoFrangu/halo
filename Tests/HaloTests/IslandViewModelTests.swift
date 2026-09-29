import CoreGraphics
import Testing
@testable import Halo

@MainActor
struct IslandViewModelTests {
    private func island() -> IslandViewModel {
        let geometry = NotchGeometry.resolve(
            screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
            safeAreaTop: 32,
            auxiliaryLeftWidth: 640,
            auxiliaryRightWidth: 640,
            menuBarHeight: 32
        )
        let island = IslandViewModel(geometry: geometry)
        island.tabsChanged([.shelf, .timer])
        return island
    }

    @Test func keepsTheTabPickedLast() {
        let island = island()
        island.selectTab(.timer)
        island.liveActivityChanged(active: true)
        #expect(island.context.tab == .timer)
    }

    @Test func backToThePlayerWhenThePickedTabGoesAway() {
        let island = island()
        island.selectTab(.timer)
        island.tabsChanged([.shelf])
        island.liveActivityChanged(active: true)
        #expect(island.context.tab == .player)
    }

    @Test func compactTucksIntoNotchWhilePointerIsOnAWing() {
        let island = island()
        island.playbackChanged(isPlaying: true, hasMedia: true)
        #expect(island.state == .compact)

        // The menu item right before the notch, under the artwork wing.
        let geometry = island.geometry
        let menuItem = CGPoint(x: geometry.notchCenterX - geometry.notchSize.width / 2 - 20, y: 950)
        island.pointerMoved(to: menuItem)
        #expect(island.state == .idle)

        island.pointerMoved(to: CGPoint(x: menuItem.x, y: 700))
        #expect(island.state == .compact)
    }
}
