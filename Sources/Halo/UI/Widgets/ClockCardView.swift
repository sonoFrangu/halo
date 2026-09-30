import SwiftUI

/// What the desktop widget shows while nothing plays: time, date and the weather. The
/// timeline redraws once a minute.
struct ClockCardView: View {
    let weather: WeatherReport?
    let width: CGFloat

    var body: some View {
        TimelineView(.everyMinute) { context in
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 52, weight: .semibold, design: .rounded).monospacedDigit())
                        .tracking(-1)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Ink.secondary)
                }
                Spacer(minLength: 12)
                if let weather {
                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: weather.symbol)
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 26, weight: .medium))
                        Text(weather.temperatureText)
                            .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Ink.primary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(weather.summary), \(weather.temperatureText)")
                }
            }
            .animation(.easeInOut(duration: 0.4), value: context.date)
        }
        .padding(Corner.widgetPadding)
        .frame(width: width)
        .background {
            WidgetBackdrop(cornerRadius: Corner.widget)
        }
    }
}
