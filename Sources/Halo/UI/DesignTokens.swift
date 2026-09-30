import SwiftUI

/// Corner radii. A shape inside a rounded container, with the same margin to both sides of
/// its corner, is concentric with it (radius = outer radius − margin), as in macOS's own
/// controls; small standalone items (icons, thumbnails, cards) all share `tile`.
enum Corner {
    /// Icons, thumbnails and cards, whatever their size.
    static let tile: CGFloat = 10
    /// Floating cards (desktop and lock screen widgets).
    static let widget: CGFloat = 24
    /// Margin inside a widget, on every side.
    static let widgetPadding: CGFloat = 16

    static func concentric(_ outer: CGFloat, inset: CGFloat) -> CGFloat {
        max(outer - inset, 2)
    }
}

/// The few levels of white text and glyphs take on the island's black, like the system's
/// label colors: the same kind of information gets the same grey everywhere.
enum Ink {
    /// Titles, values, active controls.
    static let primary = Color.white
    /// Artists, subtitles, captions, controls that are off.
    static let secondary = Color.white.opacity(0.6)
    /// Hints, timestamps, values not known yet.
    static let tertiary = Color.white.opacity(0.4)
}

/// Backgrounds, tracks and hairlines, like the system's fill colors.
enum Fill {
    /// Buttons, chips, the tracks of bars and rings, hairline borders.
    static let primary = Color.white.opacity(0.14)
    /// Tiles and quieter chips.
    static let secondary = Color.white.opacity(0.08)
    /// Large areas that only need to be told apart from the black.
    static let tertiary = Color.white.opacity(0.03)
}
