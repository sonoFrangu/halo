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
}
