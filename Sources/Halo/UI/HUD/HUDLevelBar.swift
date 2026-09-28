import SwiftUI

/// Right-wing level bar of the HUD: a slim capsule whose fill glows more the higher the
/// level, thickening while dragged. Dragging sets the level directly.
struct HUDLevelBar: View {
    let kind: HUDKind
    let level: Double
    let isMuted: Bool
    let tint: Color
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
                    .fill(fill)
                    .frame(width: max(thickness, width * CGFloat(shown)))
                    .opacity(shown > 0 ? 1 : 0)
                    .shadow(color: glow.opacity(0.65 * shown), radius: 6)
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
        .animation(.spring(duration: 0.3, bounce: 0.12), value: level)
        .animation(.spring(duration: 0.3, bounce: 0.12), value: isMuted)
        .animation(Motion.hoverFeedback, value: isDragging)
        .accessibilityElement()
        .accessibilityValue("\(Int((level * 100).rounded())) percento")
    }

    /// Brightness is warm sunlight; volume takes the artwork's color.
    private var fill: LinearGradient {
        switch kind {
        case .brightness:
            LinearGradient(
                colors: [Color(red: 1, green: 0.72, blue: 0.32), Color(red: 1, green: 0.96, blue: 0.86)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .volume:
            LinearGradient(colors: [tint.opacity(0.85), tint], startPoint: .leading, endPoint: .trailing)
        }
    }

    private var glow: Color {
        kind == .brightness ? Color(red: 1, green: 0.85, blue: 0.55) : tint
    }
}
