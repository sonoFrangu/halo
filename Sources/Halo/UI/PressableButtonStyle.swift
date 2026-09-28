import SwiftUI

/// Press feedback: a springy shrink and dim while held (dim only with Reduce Motion).
struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .scaleEffect(pressed && !reduceMotion ? 0.86 : 1)
            .opacity(pressed ? 0.7 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.1) : Motion.press, value: pressed)
    }
}
