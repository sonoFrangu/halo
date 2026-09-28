import Foundation

/// An sRGB color with components in 0...1. Plain value type so palette math stays pure,
/// testable and usable off the main actor.
struct RGBColor: Sendable, Hashable {
    var red: Double
    var green: Double
    var blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(hue: Double, saturation: Double, brightness: Double) {
        let wrappedHue = (hue.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
        let sector = wrappedHue * 6
        let chroma = brightness * saturation
        let x = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let m = brightness - chroma
        let (r, g, b): (Double, Double, Double) = switch Int(sector) {
        case 0: (chroma, x, 0)
        case 1: (x, chroma, 0)
        case 2: (0, chroma, x)
        case 3: (0, x, chroma)
        case 4: (x, 0, chroma)
        default: (chroma, 0, x)
        }
        self.init(red: r + m, green: g + m, blue: b + m)
    }

    struct HSB: Sendable, Equatable {
        var hue: Double
        var saturation: Double
        var brightness: Double
    }

    var hsb: HSB {
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let delta = maximum - minimum
        var hue = 0.0
        if delta > 0 {
            if maximum == red {
                hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
            } else if maximum == green {
                hue = (blue - red) / delta + 2
            } else {
                hue = (red - green) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return HSB(hue: hue, saturation: maximum > 0 ? delta / maximum : 0, brightness: maximum)
    }

    /// Relative luminance (Rec. 709 weights on the encoded values; good enough for ranking).
    var luminance: Double {
        0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    func distance(to other: RGBColor) -> Double {
        let dr = red - other.red
        let dg = green - other.green
        let db = blue - other.blue
        return (dr * dr + dg * dg + db * db).squareRoot()
    }
}
