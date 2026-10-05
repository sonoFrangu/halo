import SwiftUI
import Testing
@testable import Halo

@MainActor
struct NotchShapeTests {
    private let canvas = CGRect(x: 0, y: 0, width: 600, height: 240)

    private func isClose(_ a: CGFloat, _ b: CGFloat, tolerance: CGFloat = 0.01) -> Bool {
        abs(a - b) <= tolerance
    }

    @Test func boundsCoverBodyAndEars() {
        let spec = IslandShapeSpec(width: 468, height: 168, bottomRadius: 28, earRadius: 14)
        let bounds = NotchShape(spec: spec).path(in: canvas).boundingRect
        let halfSpan: CGFloat = 234 + 14
        #expect(isClose(bounds.minX, 300 - halfSpan))
        #expect(isClose(bounds.maxX, 300 + halfSpan))
        #expect(isClose(bounds.minY, 0))
        #expect(isClose(bounds.maxY, 168))
    }

    @Test func shapeIsHorizontallySymmetric() {
        let spec = IslandShapeSpec(width: 274, height: 32, bottomRadius: 12, earRadius: 6)
        let bounds = NotchShape(spec: spec).path(in: canvas).boundingRect
        #expect(isClose(bounds.midX, canvas.midX))
    }

    @Test func degenerateSizesProduceEmptyPath() {
        let spec = IslandShapeSpec(width: 0, height: 0, bottomRadius: 10, earRadius: 5)
        #expect(NotchShape(spec: spec).path(in: canvas).isEmpty)
    }

    @Test func oversizedRadiiAreClampedIntoTheBody() {
        let spec = IslandShapeSpec(width: 40, height: 20, bottomRadius: 80, earRadius: 40)
        let bounds = NotchShape(spec: spec).path(in: canvas).boundingRect
        #expect(bounds.maxY <= 20.01)
        #expect(bounds.height > 0)
    }

    @Test func animatableDataRoundTrips() {
        var shape = NotchShape(spec: IslandShapeSpec(width: 1, height: 2, bottomRadius: 3, earRadius: 4))
        let data = shape.animatableData
        shape.animatableData = AnimatablePair(AnimatablePair(10, 20), AnimatablePair(30, 40))
        #expect(shape.bodyWidth == 10)
        #expect(shape.bodyHeight == 20)
        #expect(shape.bottomRadius == 30)
        #expect(shape.earRadius == 40)
        shape.animatableData = data
        #expect(shape.bodyWidth == 1)
        #expect(shape.earRadius == 4)
    }

    @Test func smoothCornerExtentFollowsSmoothing() {
        let corner = SmoothCorner(radius: 10, smoothing: 0.6, maximumExtent: 100)
        #expect(isClose(corner.extent, 16))
        #expect(isClose(corner.smoothing, 0.6))
    }

    @Test func smoothCornerGivesUpSmoothingBeforeRadius() {
        let tight = SmoothCorner(radius: 10, smoothing: 0.6, maximumExtent: 12)
        #expect(isClose(tight.radius, 10))
        #expect(isClose(tight.extent, 12))

        let tighter = SmoothCorner(radius: 10, smoothing: 0.6, maximumExtent: 6)
        #expect(isClose(tighter.radius, 6))
        #expect(isClose(tighter.smoothing, 0))
        #expect(isClose(tighter.extent, 6))
    }

    @Test func unsmoothedCornerIsAQuarterCircle() {
        // With smoothing 0 the corner must pass through the 45° point of a circular arc.
        let radius: CGFloat = 20
        let corner = SmoothCorner(radius: radius, smoothing: 0, maximumExtent: 100)
        var path = Path()
        path.move(to: CGPoint(x: 100, y: 100 - radius))
        corner.add(
            to: &path,
            corner: CGPoint(x: 100, y: 100),
            incoming: CGVector(dx: 0, dy: -1),
            outgoing: CGVector(dx: -1, dy: 0)
        )
        let bounds = path.boundingRect
        #expect(isClose(bounds.minX, 100 - radius, tolerance: 0.05))
        #expect(isClose(bounds.maxY, 100, tolerance: 0.05))
        let offset: CGFloat = radius / CGFloat(2).squareRoot()
        let diagonal = CGPoint(x: 100 - radius + offset, y: 100 - radius + offset)
        #expect(path.strokedPath(StrokeStyle(lineWidth: 0.2)).contains(diagonal))
    }
}

/// The island closes into the hardware notch (MacBook Air 13" at "More Space": 208 × 37.5).
struct NotchClosingTests {
    private let layout = IslandLayout(notchSize: CGSize(width: 208, height: 37.5), hasPhysicalNotch: true)

    @Test func idleHidesBehindTheNotch() {
        let idle = layout.spec(for: .idle, context: IslandContext())
        #expect(idle.width < 208 && idle.height < 37.5 && idle.earRadius == 0)
    }

    /// Closing can start at any moment of an opening (the pointer passes over the notch),
    /// carrying its speed. Once the shape is back behind the notch it must stay there:
    /// a swing back out would show as a black flicker under the notch.
    @Test(arguments: [
        (IslandState.compact, IslandContext()),
        (.alert, IslandContext(alertStyle: .wings)),
        (.alert, IslandContext(alertStyle: .banner)),
        (.alert, IslandContext(alertStyle: .glyph)),
        (.expanded, IslandContext(hasMedia: true, tab: .player, showsLyrics: true)),
    ])
    func closingNeverSwingsBackOut(state: IslandState, context: IslandContext) {
        let idle = layout.spec(for: .idle, context: context)
        let open = layout.spec(for: state, context: context)
        let notch = layout.notchSize
        for (from, to, limit) in [(idle.width, open.width, notch.width), (idle.height, open.height, notch.height)] {
            for step in 0...100 {
                let interruptedAt = Double(step) * 0.005
                let start = from + Motion.opening.value(target: to - from, time: interruptedAt)
                let speed = Motion.opening.velocity(target: to - from, time: interruptedAt)
                var hasLeft = start > limit
                var isBack = false
                for millisecond in 0...2000 {
                    let value = start + Motion.closing.value(target: from - start, initialVelocity: speed, time: Double(millisecond) / 1000)
                    if isBack {
                        #expect(value <= limit)
                    } else if value > limit {
                        hasLeft = true
                    } else if hasLeft {
                        isBack = true
                    }
                }
            }
        }
    }
}

/// Content grows out of the notch's center wherever it sits, even nested in a stack.
@MainActor
struct RevealOriginTests {
    @Test func scaleIsAnchoredAtTheNotchCenter() throws {
        let view = ZStack(alignment: .topLeading) {
            Color.black
            HStack(spacing: 0) {
                Spacer().frame(width: 150)
                Rectangle().fill(.white).frame(width: 20, height: 20)
                    .visualEffect { content, proxy in
                        content.scaleEffect(0.5, anchor: IslandCanvas.notchCenter(in: proxy))
                    }
            }
            .padding(.top, 50)
        }
        .frame(width: 200, height: 100, alignment: .topLeading)
        .coordinateSpace(.named(IslandCanvas.space))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        let bitmap = NSBitmapImageRep(cgImage: image)
        var lit: [CGPoint] = []
        for y in 0..<100 {
            for x in 0..<200 where (bitmap.colorAt(x: x, y: y)?.redComponent ?? 0) > 0.5 {
                lit.append(CGPoint(x: x, y: y))
            }
        }
        // Halfway from (150, 50) to the notch center (100, 0).
        #expect(lit.map(\.x).min() == 125 && lit.map(\.x).max() == 134)
        #expect(lit.map(\.y).min() == 25 && lit.map(\.y).max() == 34)
    }
}
