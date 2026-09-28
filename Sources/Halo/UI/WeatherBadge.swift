import SwiftUI

/// "☀︎ 22°" in the expanded island's header, right-aligned in the right wing.
struct WeatherBadge: View {
    let report: WeatherReport?

    var body: some View {
        HStack(spacing: 5) {
            Spacer(minLength: 0)
            if let report {
                Image(systemName: report.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 13, weight: .medium))
                Text(report.temperatureText)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))
                    .contentTransition(.numericText(value: report.temperature))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: report)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(report.map { "\($0.summary), \($0.temperatureText)" } ?? "")
    }
}
