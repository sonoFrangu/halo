import CoreGraphics
import Testing
@testable import Halo

struct NotchGeometryTests {
    private let builtIn = CGRect(x: 0, y: 0, width: 1470, height: 956)

    @Test func physicalNotchSitsBetweenAuxiliaryAreas() {
        let geometry = NotchGeometry.resolve(
            screenFrame: builtIn,
            safeAreaTop: 32,
            auxiliaryLeftWidth: 640,
            auxiliaryRightWidth: 640,
            menuBarHeight: 32
        )
        #expect(geometry.hasPhysicalNotch)
        #expect(geometry.notchSize == CGSize(width: 190, height: 32))
        #expect(geometry.notchCenterX == 735)
    }

    @Test func notchCenterFollowsScreenOrigin() {
        let geometry = NotchGeometry.resolve(
            screenFrame: builtIn.offsetBy(dx: -1470, dy: 200),
            safeAreaTop: 32,
            auxiliaryLeftWidth: 600,
            auxiliaryRightWidth: 680,
            menuBarHeight: 32
        )
        #expect(geometry.notchCenterX == -1470 + 600 + 95)
    }

    @Test func screensWithoutNotchGetAVirtualOne() {
        let geometry = NotchGeometry.resolve(
            screenFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            safeAreaTop: 0,
            auxiliaryLeftWidth: nil,
            auxiliaryRightWidth: nil,
            menuBarHeight: 24
        )
        #expect(!geometry.hasPhysicalNotch)
        #expect(geometry.notchSize == CGSize(width: NotchGeometry.virtualNotchWidth, height: 24))
        #expect(geometry.notchCenterX == 1280)
    }

    @Test func hiddenMenuBarFallsBackToDefaultHeight() {
        let geometry = NotchGeometry.resolve(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            safeAreaTop: 0,
            auxiliaryLeftWidth: nil,
            auxiliaryRightWidth: nil,
            menuBarHeight: 0
        )
        #expect(geometry.notchSize.height == NotchGeometry.defaultMenuBarHeight)
    }

    @Test func islandRectHangsFromTopEdge() {
        let geometry = NotchGeometry.resolve(
            screenFrame: builtIn,
            safeAreaTop: 32,
            auxiliaryLeftWidth: 640,
            auxiliaryRightWidth: 640,
            menuBarHeight: 32
        )
        let rect = geometry.islandRect(width: 300, height: 40)
        #expect(rect == CGRect(x: 585, y: 916, width: 300, height: 40))
    }
}
