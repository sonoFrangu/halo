/// Picks and tunes palette colors from k-means clusters.
///
/// Large dull areas (black borders, white backgrounds) should not win over a smaller but
/// characteristic color, so clusters are ranked by sqrt(weight) × vividness, with very dark
/// and washed-out whites penalized. The winner is then clamped into a range that reads as
/// a glow on pure black without turning neon.
enum PaletteSelector {
    static func palette(from clusters: [ColorCluster]) -> ArtworkPalette {
        let ranked = clusters.sorted { score($0) > score($1) }
        guard let best = ranked.first?.center else { return .neutral }

        let primary = glow(best)
        let secondary = ranked
            .dropFirst()
            .first { $0.center.distance(to: best) > 0.2 }
            .map { support($0.center) }
            ?? derivedSecondary(from: primary)
        return ArtworkPalette(primary: primary, secondary: secondary)
    }

    static func score(_ cluster: ColorCluster) -> Double {
        let hsb = cluster.center.hsb
        let vividness = 0.25 + hsb.saturation
        let visibility: Double
        if hsb.brightness < 0.18 {
            visibility = 0.15
        } else if hsb.brightness > 0.92 && hsb.saturation < 0.1 {
            visibility = 0.35
        } else {
            visibility = 1
        }
        return cluster.weight.squareRoot() * vividness * visibility
    }

    static func glow(_ color: RGBColor) -> RGBColor {
        let hsb = color.hsb
        if hsb.saturation < 0.12 {
            return ArtworkPalette.neutral.primary
        }
        return RGBColor(
            hue: hsb.hue,
            saturation: hsb.saturation.clamped(to: 0.45...0.85),
            brightness: hsb.brightness.clamped(to: 0.72...0.98)
        )
    }

    static func support(_ color: RGBColor) -> RGBColor {
        let hsb = color.hsb
        if hsb.saturation < 0.12 {
            return ArtworkPalette.neutral.secondary
        }
        return RGBColor(
            hue: hsb.hue,
            saturation: hsb.saturation.clamped(to: 0.35...0.8),
            brightness: hsb.brightness.clamped(to: 0.45...0.8)
        )
    }

    private static func derivedSecondary(from primary: RGBColor) -> RGBColor {
        let hsb = primary.hsb
        return RGBColor(hue: hsb.hue + 0.06, saturation: hsb.saturation, brightness: hsb.brightness * 0.65)
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
