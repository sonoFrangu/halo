import SwiftUI

/// Reminder a few minutes before a meeting: calendar color, time, title and, for video
/// calls, "Partecipa". Clicking the banner joins the call or opens Calendar.
struct CalendarBanner: View {
    let alert: CalendarAlert
    let onOpen: () -> Void

    var body: some View {
        let event = alert.event
        let tint = event.color.color

        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Corner.tile, style: .continuous)
                    .fill(tint.opacity(0.22))
                Image(systemName: event.meetingURL == nil ? "calendar" : "video.fill")
                    .font(Glyph.tile)
                    .foregroundStyle(tint)
            }
            .frame(width: 34, height: 34)

            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(CalendarText.short(for: event, now: context.date)) · \(CalendarText.time(event.start))")
                        .font(Typography.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(tint)
                        .textCase(.uppercase)
                    Text(event.title)
                        .font(Typography.headline)
                        .foregroundStyle(.white)
                    if let location = event.location, !location.isEmpty, event.meetingURL == nil {
                        Text(location)
                            .font(Typography.subheadline)
                            .foregroundStyle(Ink.secondary)
                    }
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if event.meetingURL != nil {
                JoinButton(tint: tint, action: onOpen)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
