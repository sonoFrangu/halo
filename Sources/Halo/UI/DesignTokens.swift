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

/// Text styles on a fixed scale like macOS's own (title 15, headline and body 13, callout
/// 12, subheadline 11, caption 10), nothing smaller than 10 pt; views add only a weight
/// when a line needs emphasis. Numbers that are the point of a view use `display`.
enum Typography {
    static let titleSize: CGFloat = 15
    static let titleWeight: Font.Weight = .semibold

    /// Track and widget titles.
    static let title = Font.system(size: titleSize, weight: titleWeight)
    /// Banner and empty-state titles, prominent values.
    static let headline = Font.system(size: 13, weight: .semibold)
    /// Messages, artists.
    static let body = Font.system(size: 13)
    /// Labels and hints.
    static let callout = Font.system(size: 12)
    /// Secondary lines, times, small buttons.
    static let subheadline = Font.system(size: 11)
    /// Captions under items and values: the smallest text.
    static let caption = Font.system(size: 10, weight: .medium)
    /// The line being sung.
    static let lyric = Font.system(size: 16, weight: .bold)

    /// Clock, countdowns and timer presets: rounded, digits of equal width.
    static let displayLarge = display(52)
    static let display = display(34)
    static let displaySmall = display(20)
    static let displayMini = display(15)

    private static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
    }
}

/// SF Symbol sizes by role, so symbols doing the same job match and sit on the text scale.
enum Glyph {
    /// Inside rings and tab chips.
    static let small = Font.system(size: 10, weight: .semibold)
    /// Icon buttons.
    static let button = Font.system(size: 13, weight: .semibold)
    /// Beside the notch: HUD, keyboard, Focus, Siri, unlock, timers.
    static let wing = Font.system(size: 15, weight: .semibold)
    /// Inside a banner's tile.
    static let tile = Font.system(size: 15, weight: .bold)
    /// Empty states and a tab's main symbol.
    static let hero = Font.system(size: 18, weight: .semibold)
    /// A device or the weather standing on its own.
    static let display = Font.system(size: 26, weight: .light)
}
