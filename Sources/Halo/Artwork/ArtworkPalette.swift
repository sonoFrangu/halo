/// Colors derived from the current artwork, tuned to glow on a pure black island.
struct ArtworkPalette: Sendable, Equatable {
    /// Dominant, glow-ready color (EQ, glow, artwork shadow).
    var primary: RGBColor
    /// Supporting color for gradients.
    var secondary: RGBColor

    /// Used without artwork: a cool, quiet silver.
    static let neutral = ArtworkPalette(
        primary: RGBColor(red: 0.66, green: 0.68, blue: 0.74),
        secondary: RGBColor(red: 0.36, green: 0.37, blue: 0.43)
    )
}
