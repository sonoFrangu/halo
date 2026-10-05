import AppKit
import EventKit
import Observation

/// Upcoming events for the island.
@MainActor
@Observable
final class CalendarModel {
    enum Access: Equatable {
        case unknown
        case granted
        case denied
    }

    private(set) var access: Access = .unknown
    /// Events not over yet, soonest first (a few).
    private(set) var events: [CalendarEvent] = []
    /// The event shown in the island header: ongoing or starting within the hour.
    private(set) var headline: CalendarEvent?

    fileprivate func setAccess(_ access: Access) {
        self.access = access
    }

    fileprivate func update(_ events: [CalendarEvent], headline: CalendarEvent?) {
        if events != self.events {
            self.events = events
        }
        if headline != self.headline {
            self.headline = headline
        }
    }
}

/// Reads the user's calendars through EventKit and posts a reminder a few minutes before
/// each meeting.
///
/// Event driven: it refreshes on `EKEventStoreChanged`, when a calendar is checked or
/// unchecked in Calendar.app, at midnight, after wake, and at the single next moment something changes (a reminder, a start or an end), with one sleeping
/// task instead of a timer.
@MainActor
@Observable
final class CalendarController {
    let model = CalendarModel()
    private(set) var isEnabled = Preferences.calendarEnabled

    @ObservationIgnored private let alerts: AlertCenter
    @ObservationIgnored private let store: EKEventStore
    @ObservationIgnored private let reader: EventReader
    @ObservationIgnored private var fetchTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    @ObservationIgnored private var hiddenCalendarsObservation: NSKeyValueObservation?
    @ObservationIgnored private var wakeTask: Task<Void, Never>?
    @ObservationIgnored private var events: [CalendarEvent] = []
    @ObservationIgnored private var alerted: Set<String> = []

    /// Events shown in the tab.
    static let listLimit = 4

    init(alerts: AlertCenter) {
        self.alerts = alerts
        let store = EKEventStore()
        self.store = store
        reader = EventReader(store: store)
    }

    func start() {
        guard isEnabled, observers.isEmpty else { return }
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            begin()
        case .notDetermined:
            store.requestFullAccessToEvents { [weak self] granted, _ in
                Task { @MainActor [weak self] in
                    guard let self, self.isEnabled else { return }
                    if granted {
                        self.begin()
                    } else {
                        self.model.setAccess(.denied)
                    }
                }
            }
        default:
            model.setAccess(.denied)
        }
    }

    func stop() {
        for observer in observers {
            observer.center.removeObserver(observer.token)
        }
        observers.removeAll()
        hiddenCalendarsObservation = nil
        wakeTask?.cancel()
        wakeTask = nil
        fetchTask?.cancel()
        fetchTask = nil
        events = []
        model.update([], headline: nil)
        alerts.withdraw(.calendar)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.calendarEnabled = enabled
        if enabled { start() } else { stop() }
    }

    /// Opens Privacy & Security › Calendars, where a denied access can be granted.
    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Joins the call when the event has a link, otherwise opens Calendar.
    func open(_ event: CalendarEvent) {
        if let meeting = event.meetingURL {
            NSWorkspace.shared.open(meeting)
        } else if let calendar = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: calendar, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    // MARK: Refresh

    private func begin() {
        model.setAccess(.granted)
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        let changed: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        observers = [
            (center, center.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main, using: changed)),
            (center, center.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main, using: changed)),
            (workspace, workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: changed)),
        ]
        // Calendar.app writes its preferences through cfprefsd, which tells observers in
        // other processes too.
        hiddenCalendarsObservation = reader.calendarApp?.observe(\.DisabledCalendars) { _, _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        refresh()
    }

    /// Fetches off the main thread (EventKit's fetch is synchronous and can take seconds
    /// right after wake), then applies the result; a newer refresh supersedes an older one.
    private func refresh() {
        guard isEnabled else { return }
        fetchTask?.cancel()
        let reader = reader
        fetchTask = Task { [weak self] in
            let events = await reader.events(around: Date())
            guard !Task.isCancelled, let self, self.isEnabled, !self.observers.isEmpty else { return }
            self.apply(events)
        }
    }

    private func apply(_ events: [CalendarEvent]) {
        let now = Date()
        self.events = events
        model.update(
            CalendarSchedule.upcoming(events, now: now, limit: Self.listLimit),
            headline: CalendarSchedule.headline(events, now: now)
        )

        for event in CalendarSchedule.dueReminders(events, now: now, alerted: alerted) {
            alerted.insert(event.reminderKey)
            alerts.post(.calendar(CalendarAlert(event: event)))
        }
        scheduleNextRefresh(after: now)
    }

    private func scheduleNextRefresh(after now: Date) {
        wakeTask?.cancel()
        guard let next = CalendarSchedule.nextChange(events, after: now) else {
            wakeTask = nil
            return
        }
        let delay = max(1, next.timeIntervalSince(now) + 0.5)
        wakeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    // MARK: EventKit

    nonisolated fileprivate static func isDeclined(_ event: EKEvent) -> Bool {
        event.attendees?.first(where: \.isCurrentUser)?.participantStatus == .declined
    }

    nonisolated fileprivate static func event(from event: EKEvent) -> CalendarEvent {
        let title: String = event.title ?? ""
        return CalendarEvent(
            id: event.eventIdentifier ?? event.calendarItemIdentifier,
            title: title.isEmpty ? "Evento" : title,
            start: event.startDate,
            end: event.endDate,
            color: color(of: event.calendar),
            location: event.location,
            meetingURL: MeetingLink.find(in: [event.url?.absoluteString, event.location, event.notes]),
            isAllDay: event.isAllDay
        )
    }

    nonisolated private static func color(of calendar: EKCalendar?) -> RGBColor {
        guard
            let cgColor = calendar?.cgColor,
            let color = NSColor(cgColor: cgColor)?.usingColorSpace(.sRGB)
        else {
            return RGBColor(red: 0.35, green: 0.6, blue: 1)
        }
        return RGBColor(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent)
    }
}

/// Runs EventKit fetches one at a time on a private queue.
///
/// `@unchecked Sendable`: the store is only used on `queue` once handed over here.
private final class EventReader: @unchecked Sendable {
    private let store: EKEventStore
    private let queue = DispatchQueue(label: "io.github.sonofrangu.halo.calendar", qos: .utility)
    /// Calendar.app's preferences, where its sidebar keeps the unchecked calendars.
    let calendarApp = UserDefaults(suiteName: "com.apple.iCal")

    init(store: EKEventStore) {
        self.store = store
    }

    /// Events from 12 hours ago to 36 hours ahead, not cancelled nor declined, from
    /// the calendars checked in Calendar.app.
    func events(around now: Date) async -> [CalendarEvent] {
        await withCheckedContinuation { continuation in
            queue.async {
                let hidden = Set(self.calendarApp?.DisabledCalendars?["MainWindow"] as? [String] ?? [])
                let calendars = self.store.calendars(for: .event).filter { !hidden.contains($0.calendarIdentifier) }
                // Every calendar unchecked: nothing to show.
                guard !calendars.isEmpty else {
                    continuation.resume(returning: [])
                    return
                }
                let predicate = self.store.predicateForEvents(
                    withStart: now.addingTimeInterval(-12 * 3600),
                    end: now.addingTimeInterval(36 * 3600),
                    calendars: calendars
                )
                let events = self.store.events(matching: predicate)
                    .filter { $0.status != .canceled && !CalendarController.isDeclined($0) }
                    .map { CalendarController.event(from: $0) }
                continuation.resume(returning: events)
            }
        }
    }
}

private extension UserDefaults {
    /// Calendar.app's unchecked calendars by window (`MainWindow`). Named as the key so KVO
    /// observes it.
    @objc dynamic var DisabledCalendars: [String: Any]? {
        dictionary(forKey: "DisabledCalendars")
    }
}
