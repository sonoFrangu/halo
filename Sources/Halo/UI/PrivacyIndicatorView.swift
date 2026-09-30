import SwiftUI

extension PrivacyIndicators.Kind {
    /// Orange for the microphone, green for the camera, as macOS and iOS use them.
    var color: Color {
        switch self {
        case .microphone: Color(red: 1, green: 0.62, blue: 0.04)
        case .camera: Color(red: 0.19, green: 0.82, blue: 0.35)
        }
    }

    var symbol: String {
        switch self {
        case .microphone: "mic.fill"
        case .camera: "video.fill"
        }
    }

    var label: String {
        switch self {
        case .microphone: "Microfono in uso"
        case .camera: "Fotocamera in uso"
        }
    }
}

/// The in-use dot, with a soft glow.
struct PrivacyDot: View {
    let kind: PrivacyIndicators.Kind

    var body: some View {
        Circle()
            .fill(kind.color)
            .shadow(color: kind.color.opacity(0.8), radius: 3)
            .accessibilityLabel(kind.label)
    }
}

/// The glyph in the left wing when nothing else is shown there.
struct PrivacyGlyph: View {
    let kind: PrivacyIndicators.Kind

    var body: some View {
        Image(systemName: kind.symbol)
            .font(Glyph.button)
            .foregroundStyle(kind.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }
}
