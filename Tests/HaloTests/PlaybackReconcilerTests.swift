import Foundation
import Testing
@testable import Halo

struct PlaybackReconcilerTests {
    private let now = Date(timeIntervalSince1970: 50_000)
    private let routes: [CommandRoute] = [.appleScript, .direct, .adapter, .mediaKey]

    @Test func pauseIsSentOnceAndSettlesWhenTheStreamAgrees() {
        var reconciler = PlaybackReconciler()
        let sent = reconciler.request(playing: false, actual: true, now: now, routes: routes)
        #expect(sent == .send(playing: false, via: .appleScript))
        #expect(reconciler.desired == false)

        let (action, confirmed) = reconciler.streamReported(playing: false, now: now.addingTimeInterval(0.1), routes: routes)
        #expect(confirmed == .appleScript)
        #expect(action == .settled)
        #expect(reconciler.desired == nil)
        #expect(reconciler.attempt == nil)
    }

    @Test func unconfirmedRoutesHandOverToTheNext() {
        var reconciler = PlaybackReconciler()
        _ = reconciler.request(playing: false, actual: true, now: now, routes: routes)

        let first = reconciler.attemptFailed(now: now.addingTimeInterval(1.2), routes: routes)
        #expect(first.failed == .appleScript)
        #expect(first.action == .send(playing: false, via: .direct))

        let second = reconciler.attemptFailed(now: now.addingTimeInterval(2.1), routes: routes)
        #expect(second.failed == .direct)
        #expect(second.action == .send(playing: false, via: .adapter))

        let (_, confirmed) = reconciler.streamReported(playing: false, now: now.addingTimeInterval(2.4), routes: routes)
        #expect(confirmed == .adapter)
        #expect(reconciler.desired == nil)
    }

    @Test func givesUpAfterEveryRouteAndStopsClaimingTheState() {
        var reconciler = PlaybackReconciler()
        _ = reconciler.request(playing: false, actual: true, now: now, routes: [.adapter, .mediaKey])
        _ = reconciler.attemptFailed(now: now.addingTimeInterval(1.5), routes: [.adapter, .mediaKey])
        let last = reconciler.attemptFailed(now: now.addingTimeInterval(2.5), routes: [.adapter, .mediaKey])
        #expect(last.failed == .mediaKey)
        #expect(last.action == .failed)
        #expect(reconciler.desired == nil)
    }

    @Test func givesUpWhenTheClickIsTooOld() {
        var reconciler = PlaybackReconciler()
        _ = reconciler.request(playing: false, actual: true, now: now, routes: routes)
        let late = reconciler.attemptFailed(now: now.addingTimeInterval(PlaybackReconciler.lifetime + 1), routes: routes)
        #expect(late.action == .failed)
    }

    /// Pause, then play again before the pause landed: the two clicks merge; play is sent
    /// once the pause shows up, never a second command while the first is in flight.
    @Test func quickSecondClickWaitsForTheFirstCommand() {
        var reconciler = PlaybackReconciler()
        _ = reconciler.request(playing: false, actual: true, now: now, routes: routes)
        let merged = reconciler.request(playing: true, actual: true, now: now.addingTimeInterval(0.2), routes: routes)
        #expect(merged == .none)

        let (action, confirmed) = reconciler.streamReported(playing: false, now: now.addingTimeInterval(0.3), routes: routes)
        #expect(confirmed == .appleScript)
        #expect(action == .send(playing: true, via: .appleScript))

        let (settled, _) = reconciler.streamReported(playing: true, now: now.addingTimeInterval(0.4), routes: routes)
        #expect(settled == .settled)
    }

    @Test func nothingIsSentWhenThePlayerIsAlreadyThere() {
        var reconciler = PlaybackReconciler()
        let action = reconciler.request(playing: false, actual: false, now: now, routes: routes)
        #expect(action == .settled)
        #expect(reconciler.attempt == nil)
    }

    @Test func streamUpdatesWithoutAClickDoNothing() {
        var reconciler = PlaybackReconciler()
        let (action, confirmed) = reconciler.streamReported(playing: true, now: now, routes: routes)
        #expect(action == .none)
        #expect(confirmed == nil)
    }
}

struct ScriptablePlayerTests {
    @Test func buildsExplicitCommands() {
        let spotify = ScriptablePlayer(bundleIdentifier: "com.spotify.client")
        #expect(spotify?.script(for: .pause) == "tell application id \"com.spotify.client\" to pause")
        #expect(spotify?.script(for: .seek(42.5)) == "tell application id \"com.spotify.client\" to set player position to 42.500")
        #expect(ScriptablePlayer(bundleIdentifier: "com.apple.Music")?.script(for: .nextTrack) == "tell application id \"com.apple.Music\" to next track")
        #expect(ScriptablePlayer(bundleIdentifier: "com.apple.Safari") == nil)
        #expect(ScriptablePlayer(bundleIdentifier: nil) == nil)
    }
}
