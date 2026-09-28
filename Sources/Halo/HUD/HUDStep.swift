/// Level stepping for brightness and volume keys, matching macOS: 16 steps, or 64 with
/// Option+Shift, snapping to the step grid so a level set elsewhere realigns on the next
/// press.
enum HUDStep {
    static let regular = 1.0 / 16
    static let fine = 1.0 / 64

    static func next(from level: Double, up: Bool, fine isFine: Bool) -> Double {
        let step = isFine ? fine : regular
        let units = min(max(level, 0), 1) / step
        // A level within a thousandth of a step of the grid counts as on it: the display and
        // CoreAudio store Float32 and read back a hair off (87.5 % reads 0.874999881), and
        // a tighter tolerance made such a key press land on the same level again.
        let tolerance = 1e-3
        let snapped = up
            ? (units + tolerance).rounded(.down) + 1
            : (units - tolerance).rounded(.up) - 1
        return min(max(snapped * step, 0), 1)
    }
}
