import CoreGraphics
import Testing
@testable import Halo

struct IslandLayoutTests {
    static let layouts = [
        IslandLayout(notchSize: CGSize(width: 190, height: 32), hasPhysicalNotch: true),
        IslandLayout(notchSize: CGSize(width: 184, height: 24), hasPhysicalNotch: false),
        IslandLayout(notchSize: CGSize(width: 240, height: 38), hasPhysicalNotch: true),
    ]

    @Test(arguments: IslandLayoutTests.layouts)
    func statesGrowMonotonically(layout: IslandLayout) {
        let idle = layout.spec(for: .idle, hasMedia: true)
        let compact = layout.spec(for: .compact, hasMedia: true)
        let expanded = layout.spec(for: .expanded, hasMedia: true)
        #expect(idle.width <= compact.width)
        #expect(compact.width < expanded.width)
        #expect(idle.height <= compact.height)
        #expect(compact.height < expanded.height)
    }

    @Test(arguments: IslandLayoutTests.layouts)
    func idleStaysInsidePhysicalNotch(layout: IslandLayout) {
        guard layout.hasPhysicalNotch else { return }
        let idle = layout.spec(for: .idle, hasMedia: false)
        #expect(idle.width < layout.notchSize.width)
        #expect(idle.height < layout.notchSize.height)
        #expect(idle.earRadius == 0)
    }

    @Test(arguments: IslandLayoutTests.layouts)
    func canvasHasRoomForEveryShapeAndItsGlow(layout: IslandLayout) {
        let canvas = layout.canvasSize
        for hasMedia in [true, false] {
            for state in [IslandState.idle, .compact, .expanded] {
                let spec = layout.spec(for: state, hasMedia: hasMedia)
                #expect(spec.width + 2 * spec.earRadius + 2 * IslandLayout.canvasMargin.width <= canvas.width)
                #expect(spec.height + IslandLayout.canvasMargin.height <= canvas.height)
            }
        }
    }

    @Test(arguments: IslandLayoutTests.layouts)
    func expandedContentFitsInsideTheBodyBelowTheNotch(layout: IslandLayout) {
        let spec = layout.spec(for: .expanded, hasMedia: true)
        let body = CGRect(x: layout.centerX - spec.width / 2, y: 0, width: spec.width, height: spec.height)
        let belowNotch = [
            layout.artworkFrame(for: .expanded),
            layout.trackInfoFrame,
            layout.controlsFrame,
            layout.scrubberFrame,
        ]
        for frame in belowNotch {
            #expect(body.contains(frame))
            #expect(frame.minY >= layout.notchSize.height)
        }
        // Notch-row items must not sit under the physical notch.
        let notchMinX = layout.centerX - layout.notchSize.width / 2
        let notchMaxX = layout.centerX + layout.notchSize.width / 2
        #expect(layout.sourceIconFrame.maxX < notchMinX)
        #expect(layout.equalizerFrame(for: .expanded).minX > notchMaxX)
    }

    @Test(arguments: IslandLayoutTests.layouts)
    func compactContentSitsInTheWings(layout: IslandLayout) {
        let compact = layout.spec(for: .compact, hasMedia: true)
        let artwork = layout.artworkFrame(for: .compact)
        let equalizer = layout.equalizerFrame(for: .compact)
        let notchMinX = layout.centerX - layout.notchSize.width / 2
        let notchMaxX = layout.centerX + layout.notchSize.width / 2
        #expect(artwork.maxX < notchMinX)
        #expect(artwork.minX > layout.centerX - compact.width / 2)
        #expect(equalizer.minX > notchMaxX)
        #expect(equalizer.maxX < layout.centerX + compact.width / 2)
        #expect(artwork.maxY <= compact.height)
        #expect(equalizer.maxY <= compact.height)
    }
}
