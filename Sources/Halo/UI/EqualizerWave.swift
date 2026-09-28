import CoreGraphics
import Foundation

/// Bar heights for the equalizer. There is no audio tap (that would need capture
/// permissions), so the motion is a deterministic blend of sines per bar, shown only
/// while the player reports that it is actually playing.
enum EqualizerWave {
    static let barCount = 4
    /// Static heights used with Reduce Motion while playing.
    static let restingLevels: [CGFloat] = [0.55, 0.9, 0.65, 0.8]
    /// Heights while paused: small dots.
    static let pausedLevel: CGFloat = 0.2

    private static let slowFrequencies: [Double] = [1.7, 2.3, 1.9, 2.6]
    private static let fastFrequencies: [Double] = [4.1, 3.3, 4.7, 3.7]

    /// Level in `pausedLevel...1` for `bar` at `time` (seconds).
    static func level(bar: Int, time: TimeInterval) -> CGFloat {
        let index = ((bar % barCount) + barCount) % barCount
        let phase = Double(index) * 1.7
        let slow = sin(2 * .pi * slowFrequencies[index] * time + phase)
        let fast = sin(2 * .pi * fastFrequencies[index] * time + phase * 2.3)
        let value = 0.5 + 0.3 * slow + 0.2 * fast
        let level = pausedLevel + (1 - pausedLevel) * value
        return CGFloat(min(max(level, pausedLevel), 1))
    }
}
