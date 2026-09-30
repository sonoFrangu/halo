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
                        .font(Typography.displayLarge)
                        .tracking(-1)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(Typography.body.weight(.medium))
                        .foregroundStyle(Ink.secondary)
                }
                Spacer(minLength: 12)
                if let weather {
                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: weather.symbol)
                            .symbolRenderingMode(.multicolor)
                            .font(Glyph.display)
                        Text(weather.temperatureText)
                            .font(Typography.displaySmall)
                            .foregroundStyle(Ink.primary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(weather.summary), \(weather.temperatureText)")
                }
            }
            .animation(Motion.content, value: context.date)
        }
        .padding(Corner.widgetPadding)
        .frame(width: width)
        .background {
            WidgetBackdrop(cornerRadius: Corner.widget)
        }
    }
}
