import SwiftUI

/// What the calendar UI can ask for.
@MainActor
struct CalendarActions {
    var open: (CalendarEvent) -> Void
    var openSettings: () -> Void
}

/// The calendar tab: the next few events, each with its calendar color, time and a join
/// button for video calls. Relative times refresh once a minute.
struct CalendarTabView: View {
    let model: CalendarModel
    let actions: CalendarActions

    static let visibleRows = 3

    var body: some View {
        switch model.access {
        case .denied:
            message(
                symbol: "calendar.badge.exclamationmark",
                text: "Halo non può leggere il Calendario",
                button: "Apri Impostazioni",
                action: actions.openSettings
            )
        case .unknown:
            message(symbol: "calendar", text: "In attesa del permesso per il Calendario")
        case .granted where model.events.isEmpty:
            message(symbol: "calendar", text: "Nessun impegno nelle prossime ore")
        case .granted:
            TimelineView(.everyMinute) { context in
                VStack(spacing: 6) {
                    ForEach(model.events.prefix(Self.visibleRows)) { event in
                        CalendarEventRow(event: event, now: context.date, onOpen: { actions.open(event) })
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func message(symbol: String, text: String, button: String? = nil, action: (() -> Void)? = nil) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(Glyph.hero)
            Text(text)
                .font(Typography.callout.weight(.semibold))
            if let button, let action {
                Button(button, action: action)
                    .buttonStyle(PressableButtonStyle())
                    .font(Typography.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Fill.primary))
            }
        }
        .foregroundStyle(Ink.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One event: color bar, title, time, and "Partecipa" when it has a call link.
struct CalendarEventRow: View {
    let event: CalendarEvent
    let now: Date
    let onOpen: () -> Void

    var body: some View {
        let isOngoing = event.isOngoing(at: now)
        let tint = event.color.color

        HStack(spacing: 10) {
            Capsule()
                .fill(tint)
                .frame(width: 3.5, height: 26)
                .shadow(color: tint.opacity(isOngoing ? 0.8 : 0), radius: 4)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(Typography.headline)
                    .foregroundStyle(.white)
                Text(CalendarText.subtitle(for: event, now: now))
                    .font(Typography.caption.monospacedDigit())
                    .foregroundStyle(isOngoing ? tint : Ink.secondary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            if event.meetingURL != nil {
                JoinButton(tint: tint, action: onOpen)
            }
        }
        .frame(height: 30)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .combine)
    }
}

/// "Partecipa" capsule for video calls, in the calendar's color.
struct JoinButton: View {
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Partecipa", systemImage: "video.fill")
                .font(Typography.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Capsule().fill(tint.opacity(0.9)))
                .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }
}
