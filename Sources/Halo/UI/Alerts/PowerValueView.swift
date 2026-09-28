import SwiftUI

/// Right wing of the charging alert: percentage with rolling digits and a short state.
struct PowerValueView: View {
    let alert: PowerAlert

    var body: some View {
        let percent = Int((alert.level * 100).rounded())
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("\(percent)%")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(tint)
                .contentTransition(.numericText(value: Double(percent)))
            Text(caption)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .animation(.spring(duration: 0.35, bounce: 0.1), value: percent)
        .accessibilityElement(children: .combine)
    }

    private var caption: String {
        switch alert.event {
        case .connected: alert.level >= 1 ? "carica" : "in carica"
        case .disconnected: "batteria"
        case .low: "bassa"
        }
    }

    private var tint: Color {
        switch alert.event {
        case .connected: Color(red: 0.4, green: 0.9, blue: 0.5)
        case .disconnected: .white
        case .low: Color(red: 1, green: 0.4, blue: 0.35)
        }
    }
}
