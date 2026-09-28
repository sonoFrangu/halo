import SwiftUI

/// The island body as an animatable `Shape`.
///
/// All four parameters are animatable, so one shape morphs between idle, compact and
/// expanded instead of cross-fading different views. Geometry lives in `NotchOutline`.
struct NotchShape: Shape {
    var bodyWidth: CGFloat
    var bodyHeight: CGFloat
    var bottomRadius: CGFloat
    var earRadius: CGFloat

    nonisolated init(spec: IslandShapeSpec) {
        bodyWidth = spec.width
        bodyHeight = spec.height
        bottomRadius = spec.bottomRadius
        earRadius = spec.earRadius
    }

    nonisolated var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(AnimatablePair(bodyWidth, bodyHeight), AnimatablePair(bottomRadius, earRadius))
        }
        set {
            bodyWidth = newValue.first.first
            bodyHeight = newValue.first.second
            bottomRadius = newValue.second.first
            earRadius = newValue.second.second
        }
    }

    nonisolated func path(in rect: CGRect) -> Path {
        NotchOutline(
            bodyWidth: bodyWidth,
            bodyHeight: bodyHeight,
            bottomRadius: bottomRadius,
            earRadius: earRadius
        )
        .path(in: rect)
    }
}
