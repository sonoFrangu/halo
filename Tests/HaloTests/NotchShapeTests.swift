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
        #expect(isClose(bounds.minX, 300 - 234 - 14))
        #expect(isClose(bounds.maxX, 300 + 234 + 14))
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
        let diagonal = CGPoint(x: 100 - radius + radius / CGFloat(2).squareRoot(), y: 100 - radius + radius / CGFloat(2).squareRoot())
        #expect(path.strokedPath(StrokeStyle(lineWidth: 0.2)).contains(diagonal))
    }
}
