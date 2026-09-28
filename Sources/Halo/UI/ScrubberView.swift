import SwiftUI

/// Draggable progress bar with elapsed and remaining time.
///
/// The position is computed from `PlaybackTimeline` at draw time; the TimelineView only
/// ticks while the player is visible and playing, and never while dragging. The track
/// thickens on hover or drag. The drag state is a `GestureState`, so a cancelled drag
/// resets itself and releases the "keep expanded" lock.
struct ScrubberView: View {
    let timeline: PlaybackTimeline?
    let isActive: Bool
    let tint: Color
    let onScrubbingChanged: (Bool) -> Void
    let onSeek: (TimeInterval) -> Void

    @State private var isHovering = false
    @GestureState private var dragProgress: Double? = nil

    var body: some View {
        let ticks = isActive && dragProgress == nil && (timeline?.isAdvancing ?? false)

        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !ticks)) { context in
            content(at: context.date)
        }
        .onHover { hovering in
            isHovering = hovering
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
