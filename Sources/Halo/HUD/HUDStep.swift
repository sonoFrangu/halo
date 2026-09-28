/// Level stepping for brightness and volume keys, matching macOS: 16 steps, or 64 with
/// Option+Shift, snapping to the step grid so a level set elsewhere realigns on the next
/// press.
enum HUDStep {
    static let regular = 1.0 / 16
    static let fine = 1.0 / 64

    static func next(from level: Double, up: Bool, fine isFine: Bool) -> Double {
        let step = isFine ? fine : regular
        let units = min(max(level, 0), 1) / step
        // The epsilon keeps values already on the grid from being treated as off-grid.
        let snapped = up
            ? (units + 1e-6).rounded(.down) + 1
            : (units - 1e-6).rounded(.up) - 1
        return min(max(snapped * step, 0), 1)
    }
}
