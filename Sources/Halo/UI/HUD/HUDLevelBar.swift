import SwiftUI

/// Right-wing level bar of the HUD, drawn like macOS's own: a slim white capsule on a
/// translucent track that follows the level smoothly and thickens while dragged. Dragging
/// sets the level directly.
struct HUDLevelBar: View {
    let level: Double
    let isMuted: Bool
    let onChange: (Double) -> Void
    let onInteractionChanged: (Bool) -> Void

    @GestureState private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let shown = isMuted ? 0 : min(max(level, 0), 1)
            let thickness: CGFloat = isDragging ? 8 : 5

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(Color.white)
                    .frame(width: max(thickness, width * CGFloat(shown)))
                    .opacity(shown > 0 ? 1 : 0)
            }
            .frame(height: thickness)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        guard width > 0 else { return }
                        onChange(Double(min(max(value.location.x / width, 0), 1)))
                    }
            )
        }
        .onChange(of: isDragging) { _, dragging in
            onInteractionChanged(dragging)
        }
        .animation(.smooth(duration: 0.25), value: level)
        .animation(.smooth(duration: 0.25), value: isMuted)
        .animation(Motion.hoverFeedback, value: isDragging)
        .accessibilityElement()
        .accessibilityValue("\(Int((level * 100).rounded())) percento")
    }
}
