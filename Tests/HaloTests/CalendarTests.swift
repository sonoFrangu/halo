import Foundation
import Testing
@testable import Halo

struct MeetingLinkTests {
    @Test func findsCallLinksInNotesAndLocation() {
        let zoom = MeetingLink.find(in: [nil, "Sala 3", "Entra: https://us02web.zoom.us/j/8123456789?pwd=abc."])
        #expect(zoom?.absoluteString == "https://us02web.zoom.us/j/8123456789?pwd=abc")

        let meet = MeetingLink.find(in: ["https://meet.google.com/abc-defg-hij"])
        #expect(meet?.host == "meet.google.com")

        let teams = MeetingLink.find(in: [nil, nil, "<https://teams.microsoft.com/l/meetup-join/19%3ameeting_x%40thread.v2/0>"])
        #expect(teams?.host == "teams.microsoft.com")
    }

    @Test func ignoresOrdinaryLinks() {
        #expect(MeetingLink.find(in: ["https://example.com/agenda", "Via Roma 1"]) == nil)
        #expect(MeetingLink.find(in: [nil, "", nil]) == nil)
    }
}

struct CalendarScheduleTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func event(_ id: String, startsIn minutes: Double, lasting duration: Double = 30) -> CalendarEvent {
        let start = now.addingTimeInterval(minutes * 60)
        return CalendarEvent(
            id: id,
            title: id,
            start: start,
            end: start.addingTimeInterval(duration * 60),
            color: RGBColor(red: 1, green: 0, blue: 0),
            location: nil,
            meetingURL: nil
        )
    }

    @Test func upcomingDropsFinishedEventsAndSorts() {
        let events = [event("later", startsIn: 90), event("done", startsIn: -60), event("now", startsIn: -10)]
        #expect(CalendarSchedule.upcoming(events, now: now, limit: 5).map(\.id) == ["now", "later"])
    }

    @Test func remindersComeFiveMinutesBeforeAndOnlyOnce() {
        let soon = event("soon", startsIn: 4)
        let later = event("later", startsIn: 20)
        #expect(CalendarSchedule.dueReminders([soon, later], now: now, alerted: []).map(\.id) == ["soon"])
        #expect(CalendarSchedule.dueReminders([soon], now: now, alerted: [soon.reminderKey]).isEmpty)
    }

    @Test func startedMeetingsStillRemindBriefly() {
        #expect(CalendarSchedule.dueReminders([event("just", startsIn: -0.5)], now: now, alerted: []).count == 1)
        #expect(CalendarSchedule.dueReminders([event("old", startsIn: -5)], now: now, alerted: []).isEmpty)
    }

    @Test func nextChangeIsTheNearestBoundary() {
        let events = [event("a", startsIn: 30), event("b", startsIn: 120)]
        // "a" enters the header 60 min before, i.e. already; its reminder is at +25 min.
        #expect(CalendarSchedule.nextChange(events, after: now) == now.addingTimeInterval(25 * 60))
        #expect(CalendarSchedule.nextChange([], after: now) == nil)
    }

    @Test func headlineIsOngoingOrWithinTheHour() {
        #expect(CalendarSchedule.headline([event("far", startsIn: 90)], now: now) == nil)
        #expect(CalendarSchedule.headline([event("close", startsIn: 45)], now: now)?.id == "close")
        #expect(CalendarSchedule.headline([event("on", startsIn: -10)], now: now)?.id == "on")
    }
}

struct CalendarTextTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func relativeTimes() {
        #expect(CalendarText.relative(to: now.addingTimeInterval(12 * 60), now: now) == "tra 12 min")
        #expect(CalendarText.relative(to: now.addingTimeInterval(-30), now: now) == "adesso")
        #expect(CalendarText.relative(to: now.addingTimeInterval(2 * 3600), now: now) == nil)
    }

    @Test func ongoingEventsSayUntilWhen() {
        let event = CalendarEvent(
            id: "x",
            title: "Standup",
            start: now.addingTimeInterval(-600),
            end: now.addingTimeInterval(600),
            color: RGBColor(red: 0, green: 0, blue: 1),
            location: nil,
            meetingURL: nil
        )
        #expect(CalendarText.subtitle(for: event, now: now).hasPrefix("In corso · fino alle "))
        #expect(CalendarText.short(for: event, now: now) == "in corso")
    }
}
