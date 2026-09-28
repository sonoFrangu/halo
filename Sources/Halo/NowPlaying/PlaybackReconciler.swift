import Foundation

/// Brings the player to the play state the user asked for, one command route at a time.
///
/// Pure logic, driven by `NowPlayingController`: a click (`request`), what the stream
/// reports (`streamReported`) and the command in flight failing or running out of time
/// (`attemptFailed`). It sends a command only when the stream shows the player in the
/// other state and nothing is in flight, so clicks during a command merge into one intent
/// and a toggle-only route (the media key) can never undo itself. A route not confirmed
/// in time hands over to the next; when every route has been tried, or the click is too
/// old, the intent is dropped and the player's real state is shown again: the UI never
/// keeps claiming a pause that did not happen.
struct PlaybackReconciler {
    struct Attempt: Equatable {
        var target: Bool
        var route: CommandRoute
        var deadline: Date
    }

    enum Action: Equatable {
        case none
        /// Send play (`true`) or pause through the route; check back at the attempt's deadline.
        case send(playing: Bool, via: CommandRoute)
        /// The player is where the user wanted it.
        case settled
        /// Nothing got it there: show the player's real state.
        case failed
    }

    /// How long a click keeps being pursued.
    static let lifetime: TimeInterval = 6

    /// The play state the user asked for, while it is being pursued.
    private(set) var desired: Bool?
    private(set) var attempt: Attempt?
    private var expiry = Date.distantPast
    private var tried: [CommandRoute] = []
    private var actual: Bool?

    /// A click: `playing` is what the user wants, `actual` what the stream last reported.
    mutating func request(playing: Bool, actual: Bool?, now: Date, routes: [CommandRoute]) -> Action {
        if desired != playing {
            tried.removeAll()
        }
        desired = playing
        expiry = now.addingTimeInterval(Self.lifetime)
        self.actual = actual
        return advance(now: now, routes: routes)
    }

    /// The stream reported the play state. Also returns the route this confirms, if any.
    mutating func streamReported(playing: Bool, now: Date, routes: [CommandRoute]) -> (action: Action, confirmed: CommandRoute?) {
        actual = playing
        var confirmed: CommandRoute?
        if let attempt, attempt.target == playing {
            confirmed = attempt.route
            self.attempt = nil
        }
        return (advance(now: now, routes: routes), confirmed)
    }

    /// The command in flight failed outright or was not confirmed by its deadline. Also
    /// returns the route that failed.
    mutating func attemptFailed(now: Date, routes: [CommandRoute]) -> (action: Action, failed: CommandRoute?) {
        guard let attempt else { return (.none, nil) }
        self.attempt = nil
        return (advance(now: now, routes: routes), attempt.route)
    }

    private mutating func advance(now: Date, routes: [CommandRoute]) -> Action {
        guard let desired, attempt == nil else { return .none }
        if actual == desired {
            finish()
            return .settled
        }
        guard now < expiry, let route = routes.first(where: { !tried.contains($0) }) else {
            finish()
            return .failed
        }
        tried.append(route)
        attempt = Attempt(target: desired, route: route, deadline: now.addingTimeInterval(route.confirmationTimeout))
        return .send(playing: desired, via: route)
    }

    private mutating func finish() {
        desired = nil
        tried.removeAll()
    }
}
