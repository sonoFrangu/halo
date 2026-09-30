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

/// Pages of the expanded island.
enum ExpandedTab: Sendable, Equatable, CaseIterable {
    case player
    case shelf
    case clipboard
    case calendar
    case timer
}

/// What the island holds besides its state; it decides the size of alert and expanded
/// shapes. Changes are applied inside an animation so the shape morphs between sizes.
struct IslandContext: Sendable, Equatable {
    var hasMedia = false
    var alertStyle: AlertStyle = .wings
    var tab: ExpandedTab = .player
    var showsLyrics = false
    /// Width over height of the expanded artwork, see `IslandLayout.artworkAspect(for:)`.
    var artworkAspect: CGFloat = 1
}

/// Every island dimension and content frame, derived from the notch size.
///
/// Content frames are in canvas coordinates: origin at the top-left of the panel's content
/// view, with the notch centered horizontally at `centerX`. Content views are laid out at
/// their final frames and revealed by the growing shape, so nothing reflows mid-animation.
struct IslandLayout: Sendable, Equatable {
    let notchSize: CGSize
    let hasPhysicalNotch: Bool
    /// Width over height of the expanded artwork, 1 (square) to 16:9.
    let artworkAspect: CGFloat

    // MARK: Tunables

    static let expandedMinimumWidth: CGFloat = 468
    static let playerBodyHeight: CGFloat = 144
    static let lyricsPanelHeight: CGFloat = 88
    static let emptyBodyHeight: CGFloat = 64
    /// Body of the non-player tabs (shelf, calendar).
    static let tabBodyHeight: CGFloat = 122
    static let bannerMinimumWidth: CGFloat = 400
    static let bannerBodyHeight: CGFloat = 66
    static let contentInset: CGFloat = 24
    /// Tall enough for title and artist above the transport controls with a clear gap,
    /// both aligned to the artwork's edges.
    static let expandedArtworkSide: CGFloat = 84
    static let widestArtworkAspect: CGFloat = 16 / 9
    /// Room around the largest shape for its shadow and glow, so they never hit the
    /// panel edge. The margin is click-through (see `IslandViewModel`).
    static let canvasMargin = CGSize(width: 72, height: 64)

    init(notchSize: CGSize, hasPhysicalNotch: Bool, artworkAspect: CGFloat = 1) {
        self.notchSize = notchSize
        self.hasPhysicalNotch = hasPhysicalNotch
        self.artworkAspect = min(max(artworkAspect, 1), Self.widestArtworkAspect)
    }

    init(geometry: NotchGeometry, artworkAspect: CGFloat = 1) {
        self.init(notchSize: geometry.notchSize, hasPhysicalNotch: geometry.hasPhysicalNotch, artworkAspect: artworkAspect)
    }

    /// The expanded artwork follows the cover's shape so a wide one (a YouTube thumbnail)
    /// shows whole: square up to 16:9. Taller covers stay square, cropped.
    static func artworkAspect(for size: CGSize?) -> CGFloat {
        guard let size, size.width > 0, size.height > 0 else { return 1 }
        return min(max(size.width / size.height, 1), widestArtworkAspect)
    }

    // MARK: Sizes

    var compactWingWidth: CGFloat {
        (notchSize.height + 10).rounded()
    }

    /// Wing width of alerts shown beside the notch (HUD, charging).
    var hudWingWidth: CGFloat {
        max(96, (notchSize.height * 3.5).rounded())
    }

    var expandedWidth: CGFloat {
        max(Self.expandedMinimumWidth, notchSize.width + 2 * 132)
    }

    var bannerWidth: CGFloat {
        max(Self.bannerMinimumWidth, notchSize.width + 2 * 104)
    }

    func expandedBodyHeight(_ context: IslandContext) -> CGFloat {
        switch context.tab {
        case .player where context.hasMedia:
            Self.playerBodyHeight + (context.showsLyrics ? Self.lyricsPanelHeight : 0)
        case .player:
            Self.emptyBodyHeight
        case .shelf, .clipboard, .calendar, .timer:
            // Same height when empty: the shelf is a drop target and must stay easy to hit.
            Self.tabBodyHeight
        }
    }

    func spec(for state: IslandState, context: IslandContext) -> IslandShapeSpec {
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
        case .alert where context.alertStyle == .wings:
            return IslandShapeSpec(
                width: notch.width + 2 * hudWingWidth,
                height: notch.height,
                bottomRadius: min(12, notch.height / 2 - 2),
                earRadius: 6
            )
        case .alert:
            return IslandShapeSpec(
                width: bannerWidth,
                height: notch.height + Self.bannerBodyHeight,
                bottomRadius: 24,
                earRadius: 12
            )
        case .expanded:
            return IslandShapeSpec(
                width: expandedWidth,
                height: notch.height + expandedBodyHeight(context),
                bottomRadius: 28,
                earRadius: 14
            )
        }
    }

    var canvasSize: CGSize {
        let tallest = IslandContext(hasMedia: true, tab: .player, showsLyrics: true)
        let specs = [
            spec(for: .expanded, context: tallest),
            spec(for: .expanded, context: IslandContext(tab: .shelf)),
            spec(for: .alert, context: IslandContext(alertStyle: .banner)),
            spec(for: .alert, context: IslandContext(alertStyle: .wings)),
            spec(for: .compact, context: IslandContext()),
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

    // MARK: Persistent content (canvas coordinates)

    /// The artwork is one persistent view whose frame morphs between states.
    func artworkFrame(for state: IslandState) -> CGRect {
        switch state {
        case .idle, .alert:
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
            return CGRect(x: expandedMinX, y: notchSize.height + 10, width: (side * artworkAspect).rounded(), height: side)
        }
    }

    /// The equalizer lives in the compact right wing; elsewhere it fades where it is.
    func equalizerFrame(for state: IslandState) -> CGRect {
        switch state {
        case .idle, .alert:
            return CGRect(x: centerX + notchSize.width / 2 - 18, y: notchSize.height / 2 - 3, width: 8, height: 6)
        case .compact, .expanded:
            let height = max(10, notchSize.height - 18)
            return CGRect(
                x: centerX + notchSize.width / 2 + compactWingWidth / 2 - 8,
                y: (notchSize.height - height) / 2,
                width: 16,
                height: height
            )
        }
    }

    /// Right wing of the compact island (a running timer's countdown).
    var compactRightWingFrame: CGRect {
        CGRect(x: centerX + notchSize.width / 2, y: 0, width: compactWingWidth, height: notchSize.height)
    }

    /// The microphone/camera dot: centered in the right wing when the island is only up for
    /// it, otherwise at the outer edge of the left wing, clear of the artwork.
    func privacyDotFrame(alone: Bool) -> CGRect {
        let side: CGFloat = alone ? 7 : 5
        let centerX = alone
            ? compactRightWingFrame.midX
            : self.centerX - notchSize.width / 2 - compactWingWidth + 7
        return square(side: side, centerX: centerX, centerY: notchSize.height / 2)
    }

    // MARK: Expanded header (notch row)

    /// Tab switcher, in the left wing.
    var tabsFrame: CGRect {
        let wing = (expandedWidth - notchSize.width) / 2
        return CGRect(x: centerX - expandedWidth / 2 + 16, y: 0, width: wing - 24, height: notchSize.height)
    }

    /// Weather (or the inline HUD while it is showing), in the right wing.
    var headerAccessoryFrame: CGRect {
        let wing = (expandedWidth - notchSize.width) / 2
        return CGRect(x: centerX + notchSize.width / 2 + 12, y: 0, width: wing - 32, height: notchSize.height)
    }

    // MARK: Player

    /// Source app badge on the artwork's bottom-right corner.
    var sourceIconFrame: CGRect {
        let artwork = artworkFrame(for: .expanded)
        return square(side: 22, centerX: artwork.maxX - 5, centerY: artwork.maxY - 5)
    }

    var trackInfoFrame: CGRect {
        let artwork = artworkFrame(for: .expanded)
        let x = artwork.maxX + 16
        return CGRect(x: x, y: artwork.minY + 2, width: expandedMaxX - x, height: 40)
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

    var lyricsFrame: CGRect {
        let scrubber = scrubberFrame
        return CGRect(
            x: expandedMinX,
            y: scrubber.maxY + 8,
            width: expandedMaxX - expandedMinX,
            height: Self.lyricsPanelHeight - 16
        )
    }

    /// Message area of the player tab when nothing is playing.
    var emptyStateFrame: CGRect {
        CGRect(
            x: expandedMinX,
            y: notchSize.height + 4,
            width: expandedMaxX - expandedMinX,
            height: Self.emptyBodyHeight - 12
        )
    }

    // MARK: Tabs

    /// Content of the shelf and calendar tabs.
    var tabBodyFrame: CGRect {
        CGRect(
            x: centerX - expandedWidth / 2 + 16,
            y: notchSize.height + 6,
            width: expandedWidth - 32,
            height: Self.tabBodyHeight - 16
        )
    }

    // MARK: Alerts

    /// Glyph of a wings alert (HUD, charging), centered in the left wing.
    var hudGlyphFrame: CGRect {
        square(
            side: notchSize.height - 8,
            centerX: centerX - notchSize.width / 2 - hudWingWidth / 2,
            centerY: notchSize.height / 2
        )
    }

    /// Level bar across the right wing (the frame is the full-height hit area; the bar is
    /// drawn centered in it). No number beside it, as in macOS's own HUD.
    var hudBarFrame: CGRect {
        let x = centerX + notchSize.width / 2 + 14
        return CGRect(x: x, y: 0, width: hudWingWidth - 14 - 16, height: notchSize.height)
    }

    /// Whole right wing of a wings alert.
    var alertRightWingFrame: CGRect {
        let x = centerX + notchSize.width / 2 + 12
        return CGRect(x: x, y: 0, width: hudWingWidth - 12 - 16, height: notchSize.height)
    }

    /// Content of a banner alert, below the notch.
    var bannerFrame: CGRect {
        CGRect(
            x: centerX - bannerWidth / 2 + 20,
            y: notchSize.height + 4,
            width: bannerWidth - 40,
            height: Self.bannerBodyHeight - 12
        )
    }

    // MARK: Helpers

    private var expandedMinX: CGFloat {
        centerX - expandedWidth / 2 + Self.contentInset
    }

    private var expandedMaxX: CGFloat {
        centerX + expandedWidth / 2 - Self.contentInset
    }

    private func square(side: CGFloat, centerX: CGFloat, centerY: CGFloat) -> CGRect {
        CGRect(x: centerX - side / 2, y: centerY - side / 2, width: side, height: side)
    }
}
