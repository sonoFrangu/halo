import SwiftUI

/// Pure geometry of the island outline (no SwiftUI view isolation), so it can be built
/// from `Shape.path(in:)`, which is nonisolated, and tested directly.
///
/// The body hangs from the top edge of the rect, centered horizontally. Concave "ears"
/// blend it into the screen edge; the bottom corners are continuous (`SmoothCorner`).
struct NotchOutline: Sendable, Equatable {
    var bodyWidth: CGFloat
    var bodyHeight: CGFloat
    var bottomRadius: CGFloat
    var earRadius: CGFloat

    /// Corner smoothing of the bottom corners (0.6 ≈ iOS app icons).
    static let smoothing: CGFloat = 0.6
    /// Bézier tension of the ears. Above the circular 0.552 the curvature at both joins is
    /// lower, so the ear melts into the screen edge and into the body's side.
    static let earTension: CGFloat = 0.62

    func path(in rect: CGRect) -> Path {
        let width = max(bodyWidth, 0)
        let height = max(bodyHeight, 0)
        guard width > 0.5, height > 0.5 else { return Path() }

        let top = rect.minY
        let bottom = top + height
        let left = rect.midX - width / 2
        let right = rect.midX + width / 2
        let ear = min(max(earRadius, 0), height / 2, width / 4)
        let corner = SmoothCorner(
            radius: bottomRadius,
            smoothing: Self.smoothing,
            maximumExtent: min(width / 2, height - ear)
        )
        let k = 1 - Self.earTension

        var path = Path()
        path.move(to: CGPoint(x: left - ear, y: top))
        path.addLine(to: CGPoint(x: right + ear, y: top))
        if ear > 0 {
            path.addCurve(
                to: CGPoint(x: right, y: top + ear),
                control1: CGPoint(x: right + ear * k, y: top),
                control2: CGPoint(x: right, y: top + ear * k)
            )
        }
        path.addLine(to: CGPoint(x: right, y: bottom - corner.extent))
        corner.add(
            to: &path,
            corner: CGPoint(x: right, y: bottom),
            incoming: CGVector(dx: 0, dy: -1),
            outgoing: CGVector(dx: -1, dy: 0)
        )
        path.addLine(to: CGPoint(x: left + corner.extent, y: bottom))
        corner.add(
            to: &path,
            corner: CGPoint(x: left, y: bottom),
            incoming: CGVector(dx: 1, dy: 0),
            outgoing: CGVector(dx: 0, dy: -1)
        )
        path.addLine(to: CGPoint(x: left, y: top + ear))
        if ear > 0 {
            path.addCurve(
                to: CGPoint(x: left - ear, y: top),
                control1: CGPoint(x: left, y: top + ear * k),
                control2: CGPoint(x: left - ear * k, y: top)
            )
        }
        path.closeSubpath()
        return path
    }
}
