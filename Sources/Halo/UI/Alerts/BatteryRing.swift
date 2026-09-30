import SwiftUI

/// A small circular gauge: battery of one earbud, the case, or the output volume.
struct BatteryRing: View {
    /// 0...1, or `nil` while unknown.
    let value: Double?
    let symbol: String
    let caption: String
    var tint: Color = Color(red: 0.4, green: 0.9, blue: 0.5)

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .stroke(Fill.primary, lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: CGFloat(value ?? 0))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(value == nil ? Ink.tertiary : Ink.primary)
            }
            .frame(width: 28, height: 28)

            Text(value.map { "\(Int(($0 * 100).rounded()))%" } ?? caption)
                .font(.system(size: 9, weight: .semibold).monospacedDigit())
                .foregroundStyle(Ink.secondary)
                .lineLimit(1)
        }
        .animation(.spring(duration: 0.7, bounce: 0.15), value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityValue(value.map { "\(Int(($0 * 100).rounded())) percento" } ?? "sconosciuto")
    }

    private var ringColor: Color {
        guard let value else { return .clear }
        // Red from the first low-battery warning on (`HeadphoneBatteries.warningLevels`).
        return value <= 0.2 ? Color(red: 1, green: 0.35, blue: 0.3) : tint
    }
}
