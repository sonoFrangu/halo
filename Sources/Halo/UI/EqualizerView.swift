import SwiftUI

/// Animated equalizer bars. Ticks only while `isPlaying` (TimelineView is paused
/// otherwise), and becomes static with Reduce Motion.
struct EqualizerView: View {
    let isPlaying: Bool
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let animates = isPlaying && !reduceMotion

        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animates)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let count = EqualizerWave.barCount
                let spacing = proxy.size.width * 0.14
                let barWidth = max(1, (proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))

                HStack(alignment: .center, spacing: spacing) {
                    ForEach(0..<count, id: \.self) { bar in
                        Capsule()
                            .fill(tint)
                            .frame(
                                width: barWidth,
                                height: max(barWidth, proxy.size.height * level(bar: bar, time: time, animates: animates))
                            )
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: isPlaying)
        .accessibilityHidden(true)
    }

    private func level(bar: Int, time: TimeInterval, animates: Bool) -> CGFloat {
        if animates {
            return EqualizerWave.level(bar: bar, time: time)
        }
        return isPlaying ? EqualizerWave.restingLevels[bar] : EqualizerWave.pausedLevel
    }
}
