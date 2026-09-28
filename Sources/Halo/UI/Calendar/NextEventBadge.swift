import SwiftUI

/// The island header's right wing when a meeting is close: a dot in the calendar's color,
/// the title and "tra 12 min" (or "in corso"). It takes the weather's place for that hour.
struct NextEventBadge: View {
    let event: CalendarEvent

    var body: some View {
        TimelineView(.everyMinute) { context in
            HStack(spacing: 5) {
                Spacer(minLength: 0)
                Circle()
                    .fill(event.color.color)
                    .frame(width: 6, height: 6)
                Text(event.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(CalendarText.short(for: event, now: context.date))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(event.color.color)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
