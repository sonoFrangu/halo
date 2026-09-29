import SwiftUI

/// Draggable progress bar with elapsed and remaining time.
///
/// The position is computed from `PlaybackTimeline` at draw time; the TimelineView only
/// ticks while the player is visible and playing, and never while dragging. The track
/// thickens on hover or drag. The drag state is a `GestureState`, so a cancelled drag
/// resets itself and releases the "keep expanded" lock.
///
/// Hover is owned by the caller rather than kept in `@State`: in the macOS 27 SDK `@State`
/// is a macro whose plugin ships only with Xcode, so it breaks Command Line Tools builds.
struct ScrubberView: View {
    let timeline: PlaybackTimeline?
    let isActive: Bool
    let tint: Color
    let isHovering: Bool
    let onHoverChanged: (Bool) -> Void
    let onScrubbingChanged: (Bool) -> Void
    let onSeek: (TimeInterval) -> Void
    /// Fastest redraw while playing: 60 fps in the island, once a second on always-visible
    /// cards. The actual rate is lower when the fill moves less than a pixel per frame.
    var minimumInterval: TimeInterval = 1.0 / 60

    /// Pixels across the widest bar (a 440-point card on a 2x display), rounded up: ticking
    /// once per pixel of fill is as smooth as ticking every frame.
    private static let pixelsAcross: Double = 900

    /// How often the fill moves by about a pixel (every ~0.2 s for a 3-minute song), within
    /// `minimumInterval...1`: at least once a second for the time labels.
    private var tickInterval: TimeInterval {
        guard let timeline, timeline.duration > 0 else { return 1 }
        let perPixel = timeline.duration / max(timeline.rate, 1) / Self.pixelsAcross
        return min(max(minimumInterval, perPixel), 1)
    }

    @GestureState private var dragProgress: Double? = nil

    var body: some View {
        let ticks = isActive && dragProgress == nil && (timeline?.isAdvancing ?? false)

        TimelineView(.animation(minimumInterval: tickInterval, paused: !ticks)) { context in
            content(at: context.date)
        }
        .onHover { hovering in
            onHoverChanged(hovering)
        }
        .onChange(of: dragProgress != nil) { _, isDragging in
            onScrubbingChanged(isDragging)
        }
    }

    private func content(at date: Date) -> some View {
        let duration = timeline?.duration ?? 0
        let progress = dragProgress ?? timeline?.progress(at: date) ?? 0
        let elapsed = duration * progress
        let isEmphasized = (isHovering || dragProgress != nil) && duration > 0

        return HStack(spacing: 10) {
            timeLabel(timeline == nil ? "--:--" : TimeFormatting.string(elapsed), alignment: .trailing)

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.16))
                    Capsule()
                        .fill(isEmphasized ? tint : Color.white.opacity(0.9))
                        .frame(width: max(0, min(width, width * CGFloat(progress))))
                }
                .frame(height: isEmphasized ? 8 : 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(dragGesture(width: width, duration: duration))
            }

            timeLabel(timeline == nil ? "--:--" : "-" + TimeFormatting.string(duration - elapsed), alignment: .leading)
        }
        .animation(Motion.hoverFeedback, value: isEmphasized)
    }

    private func dragGesture(width: CGFloat, duration: TimeInterval) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragProgress) { value, state, _ in
                guard duration > 0, width > 0 else { return }
                state = Double(min(max(value.location.x / width, 0), 1))
            }
            .onEnded { value in
                guard duration > 0, width > 0 else { return }
                onSeek(Double(min(max(value.location.x / width, 0), 1)) * duration)
            }
    }

    private func timeLabel(_ text: String, alignment: Alignment) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.5))
            .frame(width: 44, alignment: alignment)
    }
}
