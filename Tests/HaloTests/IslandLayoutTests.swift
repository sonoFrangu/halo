import CoreGraphics
import Testing
@testable import Halo

struct IslandLayoutTests {
    static let layouts = [
        IslandLayout(notchSize: CGSize(width: 190, height: 32), hasPhysicalNotch: true),
        IslandLayout(notchSize: CGSize(width: 184, height: 24), hasPhysicalNotch: false),
        IslandLayout(notchSize: CGSize(width: 240, height: 38), hasPhysicalNotch: true),
    ]

    static let contexts: [IslandContext] = [
        IslandContext(hasMedia: true),
        IslandContext(hasMedia: false),
        IslandContext(hasMedia: true, showsLyrics: true),
        IslandContext(alertStyle: .banner),
        IslandContext(tab: .shelf),
    ]

    private let media = IslandContext(hasMedia: true)

    @Test(arguments: IslandLayoutTests.layouts)
    func statesGrowMonotonically(layout: IslandLayout) {
        let idle = layout.spec(for: .idle, context: media)
        let compact = layout.spec(for: .compact, context: media)
        let expanded = layout.spec(for: .expanded, context: media)
        #expect(idle.width <= compact.width)
        #expect(compact.width < expanded.width)
        #expect(idle.height <= compact.height)
        #expect(compact.height < expanded.height)
    }

    @Test(arguments: IslandLayoutTests.layouts)
    func idleStaysInsidePhysicalNotch(layout: IslandLayout) {
        guard layout.hasPhysicalNotch else { return }
        let idle = layout.spec(for: .idle, context: IslandContext())
        #expect(idle.width < layout.notchSize.width)
        #expect(idle.height < layout.notchSize.height)
        #expect(idle.earRadius == 0)
    }

    @Test(arguments: IslandLayoutTests.layouts)
    func canvasHasRoomForEveryShapeAndItsGlow(layout: IslandLayout) {
        let canvas = layout.canvasSize
        for context in Self.contexts {
            for state in [IslandState.idle, .compact, .alert, .expanded] {
                let spec = layout.spec(for: state, context: context)
                let neededWidth: CGFloat = spec.width + 2 * spec.earRadius + 2 * IslandLayout.canvasMargin.width
                let neededHeight: CGFloat = spec.height + IslandLayout.canvasMargin.height
                #expect(neededWidth <= canvas.width)
                #expect(neededHeight <= canvas.height)
            }
        }
    }

    @Test(arguments: IslandLayoutTests.layouts)
    func lyricsMakeThePlayerTaller(layout: IslandLayout) {
        let plain = layout.spec(for: .expanded, context: media)
        let lyrics = layout.spec(for: .expanded, context: IslandContext(hasMedia: true, showsLyrics: true))
        #expect(lyrics.height > plain.height)
        #expect(lyrics.width == plain.width)
    }

    @Test(arguments: IslandLayoutTests.layouts)
    func playerContentFitsInsideTheBodyBelowTheNotch(layout: IslandLayout) {
        let spec = layout.spec(for: .expanded, context: IslandContext(hasMedia: true, showsLyrics: true))
        let body = CGRect(x: layout.centerX - spec.width / 2, y: 0, width: spec.width, height: spec.height)
        let belowNotch = [
            layout.artworkFrame(for: .expanded),
            layout.trackInfoFrame,
            layout.controlsFrame,
            layout.scrubberFrame,
            layout.lyricsFrame,
            layout.sourceIconFrame,
        ]
        for frame in belowNotch {
            #expect(body.contains(frame))
            #expect(frame.minY >= layout.notchSize.height)
        }
    }

    @Test(arguments: IslandLayoutTests.layouts)
    func headerItemsSitInTheWings(layout: IslandLayout) {
        let notchMinX = layout.centerX - layout.notchSize.width / 2
        let notchMaxX = layout.centerX + layout.notchSize.width / 2
        let bodyMinX = layout.centerX - layout.expandedWidth / 2
        let bodyMaxX = layout.centerX + layout.expandedWidth / 2
        #expect(layout.tabsFrame.minX > bodyMinX)
        #expect(layout.tabsFrame.maxX < notchMinX)
        #expect(layout.headerAccessoryFrame.minX > notchMaxX)
        #expect(layout.headerAccessoryFrame.maxX < bodyMaxX)
    }

    @Test(arguments: IslandLayoutTests.layouts)
    func compactContentSitsInTheWings(layout: IslandLayout) {
        let compact = layout.spec(for: .compact, context: media)
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

    @Test(arguments: IslandLayoutTests.layouts)
    func bannerContentSitsBelowTheNotch(layout: IslandLayout) {
        let banner = layout.spec(for: .alert, context: IslandContext(alertStyle: .banner))
        let body = CGRect(x: layout.centerX - banner.width / 2, y: 0, width: banner.width, height: banner.height)
        #expect(body.contains(layout.bannerFrame))
        #expect(layout.bannerFrame.minY >= layout.notchSize.height)
    }

    @Test(arguments: IslandLayoutTests.layouts)
    func shelfFitsInsideItsBody(layout: IslandLayout) {
        let shelf = layout.spec(for: .expanded, context: IslandContext(tab: .shelf))
        let body = CGRect(x: layout.centerX - shelf.width / 2, y: 0, width: shelf.width, height: shelf.height)
        #expect(body.contains(layout.tabBodyFrame))
    }
}
