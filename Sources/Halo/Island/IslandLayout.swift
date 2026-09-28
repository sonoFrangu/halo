import CoreGraphics

/// Target outline of the island body for one state.
struct IslandShapeSpec: Sendable, Equatable {
    var width: CGFloat
    var height: CGFloat
    /// Radius of the continuous bottom corners.
    var bottomRadius: CGFloat
    /// Radius of the concave fillets joining the body to the top edge of the screen.
    var earRadius: CGFloat
}

/// Every island dimension and content frame, derived from the notch size.
///
/// Content frames are in canvas coordinates: origin at the top-left of the panel's content
/// view, with the notch centered horizontally at `centerX`. Content views are laid out at
/// their final frames and revealed by the growing shape, so nothing reflows mid-animation.
struct IslandLayout: Sendable, Equatable {
    let notchSize: CGSize
    let hasPhysicalNotch: Bool

    // MARK: Tunables

    static let expandedMediaMinimumWidth: CGFloat = 468
    static let expandedMediaBodyHeight: CGFloat = 136
    static let expandedEmptyMinimumWidth: CGFloat = 320
    static let expandedEmptyBodyHeight: CGFloat = 52
    static let contentInset: CGFloat = 24
    static let expandedArtworkSide: CGFloat = 76
    /// Room around the largest shape for its shadow and glow, so they never hit the
    /// panel edge. The margin is click-through (see `IslandController`).
    static let canvasMargin = CGSize(width: 72, height: 64)

    init(notchSize: CGSize, hasPhysicalNotch: Bool) {
        self.notchSize = notchSize
        self.hasPhysicalNotch = hasPhysicalNotch
    }

    init(geometry: NotchGeometry) {
        self.init(notchSize: geometry.notchSize, hasPhysicalNotch: geometry.hasPhysicalNotch)
    }

    // MARK: Shapes

    var compactWingWidth: CGFloat {
        (notchSize.height + 10).rounded()
    }

    /// Wider than the compact wings: the right one holds the level bar and its value.
    var hudWingWidth: CGFloat {
        max(96, (notchSize.height * 3.5).rounded())
    }

    func spec(for state: IslandState, hasMedia: Bool) -> IslandShapeSpec {
        let notch = notchSize
        switch state {
        case .idle where hasPhysicalNotch:
            // Slightly smaller than the hardware notch so it stays hidden behind it even if
            // the reported geometry is a point off.
            return IslandShapeSpec(
                width: notch.width - 4,
                height: notch.height - 2,
                bottomRadius: min(10, (notch.height - 2) / 2),
                earRadius: 0
            )
        case .idle:
            return IslandShapeSpec(
                width: notch.width,
                height: notch.height,
                bottomRadius: min(9, notch.height / 2),
                earRadius: 5
            )
        case .compact:
            return IslandShapeSpec(
                width: notch.width + 2 * compactWingWidth,
                height: notch.height,
                bottomRadius: min(12, notch.height / 2 - 2),
                earRadius: 6
            )
        case .hud:
            return IslandShapeSpec(
                width: notch.width + 2 * hudWingWidth,
                height: notch.height,
                bottomRadius: min(12, notch.height / 2 - 2),
                earRadius: 6
            )
        case .expanded where hasMedia:
            return IslandShapeSpec(
                width: expandedWidth(hasMedia: true),
                height: notch.height + Self.expandedMediaBodyHeight,
                bottomRadius: 28,
                earRadius: 14
            )
        case .expanded:
            return IslandShapeSpec(
                width: expandedWidth(hasMedia: false),
                height: notch.height + Self.expandedEmptyBodyHeight,
                bottomRadius: 22,
                earRadius: 12
            )
        }
    }

    func expandedWidth(hasMedia: Bool) -> CGFloat {
        hasMedia
            ? max(Self.expandedMediaMinimumWidth, notchSize.width + 2 * 132)
            : max(Self.expandedEmptyMinimumWidth, notchSize.width + 2 * 70)
    }

    var canvasSize: CGSize {
        let specs = [
            spec(for: .expanded, hasMedia: true),
            spec(for: .expanded, hasMedia: false),
            spec(for: .compact, hasMedia: true),
            spec(for: .hud, hasMedia: true),
        ]
        let width = specs.map { $0.width + 2 * $0.earRadius }.max() ?? 0
        let height = specs.map(\.height).max() ?? 0
        return CGSize(
            width: (width + 2 * Self.canvasMargin.width).rounded(.up),
            height: (height + Self.canvasMargin.height).rounded(.up)
        )
    }

    var centerX: CGFloat {
        canvasSize.width / 2
    }

    // MARK: Content frames (canvas coordinates)

    /// The artwork is one persistent view whose frame morphs between states.
    func artworkFrame(for state: IslandState) -> CGRect {
        switch state {
        case .idle, .hud:
            // Slides inward under the notch while shrinking.
            return square(side: 10, centerX: centerX - notchSize.width / 2 + 14, centerY: notchSize.height / 2)
        case .compact:
            return square(
                side: max(14, notchSize.height - 12),
                centerX: centerX - notchSize.width / 2 - compactWingWidth / 2,
                centerY: notchSize.height / 2
            )
        case .expanded:
            let side = Self.expandedArtworkSide
            return CGRect(x: expandedMinX, y: notchSize.height + 10, width: side, height: side)
        }
    }

    /// The equalizer is persistent too: right wing when compact, top-right when expanded.
    func equalizerFrame(for state: IslandState) -> CGRect {
        switch state {
        case .idle, .hud:
            return CGRect(x: centerX + notchSize.width / 2 - 18, y: notchSize.height / 2 - 3, width: 8, height: 6)
        case .compact:
            let height = max(10, notchSize.height - 18)
            return CGRect(
                x: centerX + notchSize.width / 2 + compactWingWidth / 2 - 8,
                y: (notchSize.height - height) / 2,
                width: 16,
                height: height
            )
        case .expanded:
            let height = max(10, notchSize.height - 18)
            return CGRect(x: expandedMaxX - 18, y: (notchSize.height - height) / 2, width: 18, height: height)
        }
    }

    /// Source app icon, in the notch row's left wing.
    var sourceIconFrame: CGRect {
        square(side: 18, centerX: expandedMinX + 9, centerY: notchSize.height / 2)
    }

    var trackInfoFrame: CGRect {
        let artwork = artworkFrame(for: .expanded)
        let x = artwork.maxX + 16
        return CGRect(x: x, y: artwork.minY + 4, width: expandedMaxX - x, height: 40)
    }

    var controlsFrame: CGRect {
        let artwork = artworkFrame(for: .expanded)
        let x = artwork.maxX + 16
        return CGRect(x: x, y: artwork.maxY - 36, width: expandedMaxX - x, height: 36)
    }

    var scrubberFrame: CGRect {
        let artwork = artworkFrame(for: .expanded)
        return CGRect(x: expandedMinX, y: artwork.maxY + 14, width: expandedMaxX - expandedMinX, height: 20)
    }

    var emptyStateFrame: CGRect {
        let width = expandedWidth(hasMedia: false) - 2 * Self.contentInset
        return CGRect(x: centerX - width / 2, y: notchSize.height + 6, width: width, height: 40)
    }

    // MARK: HUD frames (canvas coordinates)

    /// Brightness/volume glyph, centered in the left wing.
    var hudGlyphFrame: CGRect {
        square(
            side: notchSize.height - 8,
            centerX: centerX - notchSize.width / 2 - hudWingWidth / 2,
            centerY: notchSize.height / 2
        )
    }

    /// Level bar (the frame is the full-height hit area; the bar is drawn centered in it).
    var hudBarFrame: CGRect {
        let x = centerX + notchSize.width / 2 + 14
        return CGRect(x: x, y: 0, width: hudWingWidth - 14 - 16 - 32, height: notchSize.height)
    }

    /// Numeric value after the bar.
    var hudValueFrame: CGRect {
        let bar = hudBarFrame
        return CGRect(x: bar.maxX + 6, y: 0, width: 26, height: notchSize.height)
    }

    // MARK: Helpers

    private var expandedMinX: CGFloat {
        centerX - expandedWidth(hasMedia: true) / 2 + Self.contentInset
    }

    private var expandedMaxX: CGFloat {
        centerX + expandedWidth(hasMedia: true) / 2 - Self.contentInset
    }

    private func square(side: CGFloat, centerX: CGFloat, centerY: CGFloat) -> CGRect {
        CGRect(x: centerX - side / 2, y: centerY - side / 2, width: side, height: side)
    }
}
