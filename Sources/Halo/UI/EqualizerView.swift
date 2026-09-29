import AppKit
import SwiftUI

/// Equalizer bars. While playing they move in short bursts, when the bars appear (playback
/// starts, the island returns to compact) and when the track changes, then rest; static
/// with Reduce Motion or in Low Power Mode.
///
/// The motion runs in Core Animation: each bar gets one looping keyframe track baked from
/// `EqualizerWave`, and the render server plays it at the display's refresh rate, so Halo
/// does no work per frame (a SwiftUI `TimelineView` cost about 18% CPU). Bursts rather than
/// endless motion because every animated frame still costs WindowServer a composite: about
/// 11% CPU at 60 fps for as long as the music plays.
struct EqualizerView: View {
    let isPlaying: Bool
    /// A new value (the track) starts a new burst.
    let track: String
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.reducesEffects) private var reducesEffects

    var body: some View {
        EqualizerBars(
            isPlaying: isPlaying,
            animates: isPlaying && !reduceMotion && !reducesEffects,
            track: track,
            tint: NSColor(tint).cgColor
        )
        .accessibilityHidden(true)
    }
}

private struct EqualizerBars: NSViewRepresentable {
    let isPlaying: Bool
    let animates: Bool
    let track: String
    let tint: CGColor

    func makeNSView(context: Context) -> EqualizerLayerView {
        EqualizerLayerView()
    }

    func updateNSView(_ view: EqualizerLayerView, context: Context) {
        view.update(isPlaying: isPlaying, animates: animates, track: track, tint: tint)
    }
}

final class EqualizerLayerView: NSView {
    private let bars: [CALayer] = (0..<EqualizerWave.barCount).map { _ in CALayer() }
    private var isPlaying = false
    private var animates = false
    private var track = ""
    /// A burst is running.
    private var isWaving = false
    private var burstEnd: DispatchWorkItem?

    private static let animationKey = "wave"
    static let burstDuration: TimeInterval = 5
    /// Same feel as the spring the SwiftUI version used between playing and paused.
    private static let settleDuration: CFTimeInterval = 0.35

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
        for bar in bars {
            bar.actions = ["position": NSNull(), "bounds": NSNull(), "cornerRadius": NSNull()]
            layer?.addSublayer(bar)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(isPlaying: Bool, animates: Bool, track: String, tint: CGColor) {
        for bar in bars where bar.backgroundColor != tint {
            bar.backgroundColor = tint
        }
        let startsBurst = animates && (!self.animates || track != self.track)
        guard startsBurst || isPlaying != self.isPlaying || animates != self.animates else { return }
        self.isPlaying = isPlaying
        self.animates = animates
        self.track = track
        burstEnd?.cancel()
        if startsBurst {
            isWaving = true
            let end = DispatchWorkItem { [weak self] in
                self?.isWaving = false
                self?.applyMotion(settling: true)
            }
            burstEnd = end
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.burstDuration, execute: end)
        } else if !animates {
            isWaving = false
        }
        applyMotion(settling: true)
    }

    override func layout() {
        super.layout()
        applyMotion(settling: false)
    }

    private var barWidth: CGFloat {
        let count = CGFloat(EqualizerWave.barCount)
        let spacing = bounds.width * 0.14
        return max(1, (bounds.width - spacing * (count - 1)) / count)
    }

    private func height(for level: CGFloat) -> CGFloat {
        max(barWidth, bounds.height * level)
    }

    /// Lays the bars out and starts, stops or keeps their motion.
    private func applyMotion(settling: Bool) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let width = barWidth
        let spacing = bounds.width * 0.14
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, bar) in bars.enumerated() {
            let current = bar.presentation()?.bounds.height ?? bar.bounds.height
            let target = height(for: staticLevel(bar: index))
            bar.position = CGPoint(x: CGFloat(index) * (width + spacing) + width / 2, y: bounds.midY)
            bar.bounds = CGRect(x: 0, y: 0, width: width, height: target)
            bar.cornerRadius = width / 2

            if isWaving {
                if settling || bar.animation(forKey: Self.animationKey) == nil {
                    bar.add(waveAnimation(bar: index), forKey: Self.animationKey)
                }
            } else {
                bar.removeAnimation(forKey: Self.animationKey)
                if settling && current != target {
                    let settle = CASpringAnimation(keyPath: "bounds.size.height")
                    settle.fromValue = current
                    settle.toValue = target
                    settle.damping = 18
                    settle.stiffness = 320
                    settle.duration = Self.settleDuration
                    bar.add(settle, forKey: "settle")
                }
            }
        }
        CATransaction.commit()
    }

    private func staticLevel(bar: Int) -> CGFloat {
        isPlaying ? EqualizerWave.restingLevels[bar] : EqualizerWave.pausedLevel
    }

    private func waveAnimation(bar: Int) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "bounds.size.height")
        animation.values = EqualizerWave.keyframes(bar: bar).map { height(for: $0) }
        animation.calculationMode = .cubic
        animation.duration = EqualizerWave.period
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        // Phase from the wall clock, as the TimelineView version: bars restart where the
        // wave is now rather than from zero.
        animation.timeOffset = Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: EqualizerWave.period)
        return animation
    }
}
