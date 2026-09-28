import SwiftUI

/// A continuous ("squircle") corner built with Figma's corner-smoothing construction:
/// a Bézier ease-in, a shortened circular arc, and a mirrored ease-out. Curvature ramps up
/// gradually instead of jumping from 0 to 1/r as with a plain arc, which is what makes
/// Apple's corners look soft.
///
/// Geometry is expressed in corner-local coordinates: `α` runs from the corner back along
/// the incoming edge, `β` along the outgoing edge. The corner spans `extent` on both.
struct SmoothCorner: Equatable {
    let radius: CGFloat
    let smoothing: CGFloat
    /// Length consumed on each adjacent edge: `(1 + smoothing) × radius`.
    let extent: CGFloat

    private let a: CGFloat
    private let b: CGFloat
    private let c: CGFloat
    private let d: CGFloat
    private let arcSweep: CGFloat

    /// - Parameter maximumExtent: space available on each edge. Smoothing is reduced first,
    ///   then the radius, so the corner always fits.
    init(radius: CGFloat, smoothing: CGFloat, maximumExtent: CGFloat) {
        var r = max(radius, 0)
        var s = min(max(smoothing, 0), 1)
        let limit = max(maximumExtent, 0)
        if (1 + s) * r > limit {
            s = r > 0 ? max(0, limit / r - 1) : 0
            if (1 + s) * r > limit {
                r = limit
                s = 0
            }
        }

        let p = (1 + s) * r
        let arcMeasure = (CGFloat.pi / 2) * (1 - s)
        let arcSectionLength = sin(arcMeasure / 2) * r * CGFloat(2).squareRoot()
        let angleAlpha = (CGFloat.pi / 2 - arcMeasure) / 2
        let p3ToP4Distance = r * tan(angleAlpha / 2)
        let angleBeta = (CGFloat.pi / 4) * s
        let c = p3ToP4Distance * cos(angleBeta)
        let d = c * tan(angleBeta)
        let b = (p - arcSectionLength - c - d) / 3

        self.radius = r
        self.smoothing = s
        self.extent = p
        self.a = 2 * b
        self.b = b
        self.c = c
        self.d = d
        self.arcSweep = arcMeasure
    }

    /// Appends the corner to `path`, which must currently be at `corner + extent × incoming`.
    ///
    /// - Parameters:
    ///   - corner: the sharp corner being rounded.
    ///   - incoming: unit vector from the corner back towards the path's current point.
    ///   - outgoing: unit vector from the corner along the edge that follows.
    func add(to path: inout Path, corner: CGPoint, incoming: CGVector, outgoing: CGVector) {
        func point(_ alpha: CGFloat, _ beta: CGFloat) -> CGPoint {
            CGPoint(
                x: corner.x + alpha * incoming.dx + beta * outgoing.dx,
                y: corner.y + alpha * incoming.dy + beta * outgoing.dy
            )
        }

        let p = extent
        let arcStart = (alpha: p - a - b - c, beta: d)

        // Ease-in from the straight edge onto the arc.
        path.addCurve(
            to: point(arcStart.alpha, arcStart.beta),
            control1: point(p - a, 0),
            control2: point(p - a - b, 0)
        )

        // Circular arc around (r, r), approximated by one cubic. The arc is symmetric about
        // the corner's diagonal, so its end and second control are mirrored (α ↔ β).
        let control = arcControl(from: arcStart)
        path.addCurve(
            to: point(arcStart.beta, arcStart.alpha),
            control1: point(control.alpha, control.beta),
            control2: point(control.beta, control.alpha)
        )

        // Ease-out onto the next straight edge.
        path.addCurve(
            to: point(0, p),
            control1: point(0, p - a - b),
            control2: point(0, p - a)
        )
    }

    /// First control point of the cubic approximating the arc that starts at `start`.
    private func arcControl(from start: (alpha: CGFloat, beta: CGFloat)) -> (alpha: CGFloat, beta: CGFloat) {
        guard radius > 0, arcSweep > 0 else { return start }
        let handle = 4 / 3 * tan(arcSweep / 4) * radius
        // Tangent at `start`: perpendicular to the radius, oriented towards the arc's end.
        let radial = (alpha: start.alpha - radius, beta: start.beta - radius)
        var tangent = (alpha: -radial.beta, beta: radial.alpha)
        let towardsEnd = (alpha: start.beta - start.alpha, beta: start.alpha - start.beta)
        if tangent.alpha * towardsEnd.alpha + tangent.beta * towardsEnd.beta < 0 {
            tangent = (alpha: -tangent.alpha, beta: -tangent.beta)
        }
        let length = (tangent.alpha * tangent.alpha + tangent.beta * tangent.beta).squareRoot()
        guard length > 0 else { return start }
        return (
            alpha: start.alpha + tangent.alpha / length * handle,
            beta: start.beta + tangent.beta / length * handle
        )
    }
}
