import SwiftUI

/// Synced lyrics under the player, Apple Music style: the sung line centered, bright and
/// tinted with the artwork's colors, neighbours fading out; the column glides to the next
/// line with a spring. Tapping a line seeks there. While `focus` is set (the lyrics were
/// scrolled by hand) the column centers that line instead of the sung one.
///
/// The view redraws only when the line changes: the `TimelineView` gets an explicit list
/// of the wall-clock moments the next lines start (recomputed whenever the playback
/// timeline changes, e.g. on seek or pause), so nothing ticks in between.
struct LyricsPanel: View {
    let lines: [LyricLine]
    let timeline: PlaybackTimeline?
    /// Seconds lines appear ahead of their timestamps.
    let lead: TimeInterval
    let palette: ArtworkPalette
    let isVisible: Bool
    var focus: Double?
    let onSeek: (TimeInterval) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let lineHeight: CGFloat = 24

    var body: some View {
        let dates = isVisible
            ? timeline.map { LyricsTimeline.changeDates(for: lines, timeline: $0, lead: lead, from: Date(), limit: 512) } ?? []
            : []

        TimelineView(.explicit(dates)) { context in
            let current = timeline.flatMap {
                LyricsTimeline.displayedIndex(at: context.date, in: lines, timeline: $0, lead: lead)
            }
            column(current: current)
        }
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.28),
                    .init(color: .black, location: 0.72),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipped()
    }

    private func column(current: Int?) -> some View {
        let lineHeight = Self.lineHeight
        return GeometryReader { proxy in
            // `.clipped()` hides the lines scrolled out of the panel but they still take
            // clicks, and the past ones sit over the play/pause button and the progress
            // bar: only lines inside the panel can be tapped.
            let reach = Int((proxy.size.height / 2 - lineHeight / 2) / lineHeight)
            let center = focus ?? Double(current ?? -1)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    let distance = Int(abs(Double(index) - center).rounded())
                    lineView(line, isCurrent: index == current, distance: distance)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: lineHeight)
                        .contentShape(Rectangle())
                        .onTapGesture { onSeek(line.time) }
                        .allowsHitTesting(distance <= reach)
                }
            }
            .offset(y: proxy.size.height / 2 - lineHeight / 2 - CGFloat(center) * lineHeight)
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.55, bounce: 0.12), value: current)
    }

    private func lineView(_ line: LyricLine, isCurrent: Bool, distance: Int) -> some View {
        Text(line.text.isEmpty ? "♪" : line.text)
            .font(.system(size: 16, weight: .bold))
            .tracking(-0.2)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(isCurrent ? AnyShapeStyle(currentLineStyle) : AnyShapeStyle(Color.white.opacity(opacity(forDistance: distance))))
            .scaleEffect(isCurrent || reduceMotion ? 1 : 0.9, anchor: .leading)
    }

    private var currentLineStyle: LinearGradient {
        LinearGradient(
            colors: [.white, palette.primary.color, palette.secondary.color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func opacity(forDistance distance: Int) -> Double {
        switch distance {
        // The centered line while scrolling by hand (the sung one has its gradient).
        case 0: 0.85
        case 1: 0.42
        case 2: 0.22
        default: 0.1
        }
    }
}
