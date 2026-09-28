import AppKit
import ApplicationServices

/// Owns the adapter processes, keeps `NowPlayingModel` in sync with them and delivers the
/// player's commands.
///
/// Commands take the most reliable route available for the playing app (see
/// `CommandRoute`): AppleScript for Spotify and Music, then MediaRemote in-process, the
/// adapter, and the keyboard's media key. Play/pause goes through `PlaybackReconciler`,
/// which moves to the next route when the stream does not confirm the change in time.
@MainActor
final class NowPlayingController {
    let model: NowPlayingModel

    private static let maximumRestartAttempts = 3

    /// What is known about the routes for one app.
    private struct RouteMemory {
        var working: CommandRoute?
        var failed: Set<CommandRoute> = []
    }

    private var resources: AdapterResources?
    private var stream: AdapterStream?
    private var commands: AdapterCommandRunner?
    /// Distinguishes events of the current stream from a previous, already replaced one.
    private var generation = 0
    private var isStopping = false
    private var restartAttempts = 0
    private var restartTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?

    /// The last state reported by the stream: the truth the UI falls back to.
    private var streamSnapshot: NowPlayingSnapshot?
    private var reconciler = PlaybackReconciler()
    private var attemptTask: Task<Void, Never>?
    /// Track and position shown while a click is being pursued.
    private var optimistic: (title: String, timeline: PlaybackTimeline?)?
    private var routeMemory: [String: RouteMemory] = [:]
    private let direct = DirectMediaRemote()
    private let scripts = ScriptRunner()
    private var scriptsPrewarmed = false
    /// Apps whose control the user refused in the Automation prompt.
    private(set) var automationDenied: Set<String> = []
    /// An AppleScript command went through at least once.
    private(set) var automationGranted = false

    init(model: NowPlayingModel) {
        self.model = model
    }

    // MARK: Lifecycle

    func start() {
        switch AdapterResources.locate(in: .main) {
        case .success(let resources):
            self.resources = resources
            commands = AdapterCommandRunner(resources: resources)
            launchStream()
        case .failure(let error):
            Log.adapter.error("\(error.description, privacy: .public)")
            model.availability = .unavailable(error.description)
        }
    }

    func stop() {
        isStopping = true
        restartTask?.cancel()
        artworkTask?.cancel()
        attemptTask?.cancel()
        stream?.stop()
        stream = nil
        commands?.shutdown()
    }

    // MARK: Controls

    /// Asks for the opposite of what is on screen. The button changes at once; the
    /// reconciler then gets the player there (or the real state comes back).
    func togglePlayPause() {
        guard let shown = model.snapshot else { return }
        let playing = !shown.isPlaying
        let now = Date()
        optimistic = (shown.title, shown.timeline?.settingPlaying(playing, at: now))
        let action = reconciler.request(
            playing: playing,
            actual: streamSnapshot?.isPlaying,
            now: now,
            routes: playbackRoutes()
        )
        perform(action)
        refreshDisplay()
    }

    func nextTrack() {
        send(.nextTrack)
    }

    func previousTrack() {
        send(.previousTrack)
    }

    func seek(to position: TimeInterval) {
        if let snapshot = model.snapshot {
            model.snapshot = snapshot.seeking(to: position, at: Date())
        }
        send(.seek(position))
    }

    /// Brings the playing app to the front (Safari for a YouTube tab).
    func openSourceApp() {
        guard
            let identifier = model.snapshot?.sourceBundleIdentifier,
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
        else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: Play/pause

    private var currentApp: String? {
        streamSnapshot?.sourceBundleIdentifier
    }

    /// The routes to try for the playing app: the one that worked last first, the ones
    /// that failed last.
    private func playbackRoutes() -> [CommandRoute] {
        let app = currentApp
        var available: [CommandRoute] = []
        if let app, ScriptablePlayer(bundleIdentifier: app) != nil, !automationDenied.contains(app) {
            available.append(.appleScript)
        }
        available.append(.direct)
        available.append(.adapter)
        if AXIsProcessTrusted() {
            available.append(.mediaKey)
        }
        let memory = routeMemory[app ?? ""] ?? RouteMemory()
        let working = available.filter { $0 == memory.working }
        let untried = available.filter { $0 != memory.working && !memory.failed.contains($0) }
        let failed = available.filter { $0 != memory.working && memory.failed.contains($0) }
        return working + untried + failed
    }

    private func perform(_ action: PlaybackReconciler.Action) {
        switch action {
        case .none:
            break
        case .send(let playing, let route):
            Log.adapter.info("\(playing ? "play" : "pause", privacy: .public) → \(self.currentApp ?? "?", privacy: .public) via \(route.rawValue, privacy: .public)")
            scheduleAttemptCheck()
            deliverPlayback(playing, via: route)
        case .settled:
            optimistic = nil
        case .failed:
            optimistic = nil
            Log.adapter.error("play/pause did not reach \(self.currentApp ?? "?", privacy: .public) by any route; showing its real state")
        }
    }

    private func deliverPlayback(_ playing: Bool, via route: CommandRoute) {
        let command: PlayerCommand = playing ? .play : .pause
        let delivered: Bool
        switch route {
        case .appleScript:
            // The script answers asynchronously: an error fails this attempt only if it is
            // still the one in flight (the reconciler may have moved on after its deadline).
            let attempt = reconciler.attempt
            delivered = runScript(for: command) { [weak self] error in
                guard error != nil, let self, self.reconciler.attempt == attempt else { return }
                self.attemptFailed()
            }
        case .direct:
            delivered = command.mediaRemote.map { direct.send($0) } ?? false
        case .adapter:
            delivered = sendThroughAdapter(command)
        case .mediaKey:
            // A toggle: the reconciler asks for it only while the stream shows the other state.
            delivered = MediaKeyPoster.press(.playPause)
        }
        if !delivered {
            attemptFailed()
        }
    }

    private func scheduleAttemptCheck() {
        attemptTask?.cancel()
        guard let attempt = reconciler.attempt else { return }
        let delay = max(0, attempt.deadline.timeIntervalSinceNow)
        attemptTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, self.reconciler.attempt == attempt else { return }
            self.attemptFailed()
        }
    }

    private func attemptFailed() {
        let (action, failed) = reconciler.attemptFailed(now: Date(), routes: playbackRoutes())
        if let failed {
            Log.adapter.info("\(failed.rawValue, privacy: .public) did not change the play state of \(self.currentApp ?? "?", privacy: .public) in time")
            remember(failed, worked: false)
        }
        perform(action)
        refreshDisplay()
    }

    private func remember(_ route: CommandRoute, worked: Bool) {
        let app = currentApp ?? ""
        var memory = routeMemory[app, default: RouteMemory()]
        if worked {
            memory.working = route
            memory.failed.remove(route)
        } else {
            memory.failed.insert(route)
            if memory.working == route {
                memory.working = nil
            }
        }
        routeMemory[app] = memory
    }

    // MARK: Other commands

    /// Skips and seeks cannot be confirmed from the stream (a "previous" may just restart
    /// the track), so they take the route known to work: AppleScript for Spotify and Music,
    /// else the one that last carried a play/pause, else the adapter.
    private func send(_ command: PlayerCommand) {
        if ScriptablePlayer(bundleIdentifier: currentApp) != nil, !automationDenied.contains(currentApp ?? "") {
            let sent = runScript(for: command) { [weak self] error in
                if error != nil {
                    _ = self?.sendThroughAdapter(command)
                }
            }
            if sent { return }
        }
        switch routeMemory[currentApp ?? ""]?.working {
        case .direct?:
            if sendDirect(command) { return }
        case .mediaKey?:
            if let key = command.mediaKey, MediaKeyPoster.press(key) { return }
        default:
            break
        }
        _ = sendThroughAdapter(command)
    }

    private func sendDirect(_ command: PlayerCommand) -> Bool {
        if case .seek(let position) = command {
            return direct.seek(to: position)
        }
        return command.mediaRemote.map { direct.send($0) } ?? false
    }

    private func sendThroughAdapter(_ command: PlayerCommand) -> Bool {
        guard let commands else { return false }
        if case .seek(let position) = command {
            commands.seek(to: position)
        } else if let id = command.mediaRemote {
            commands.send(id)
        }
        return true
    }

    /// Runs the command's AppleScript for the playing app; `completion` gets the
    /// AppleScript error number (`nil` on success). Returns `false` if the app is not
    /// scriptable.
    private func runScript(for command: PlayerCommand, completion: @escaping (Int?) -> Void) -> Bool {
        guard let player = ScriptablePlayer(bundleIdentifier: currentApp) else { return false }
        let source = player.script(for: command)
        let scripts = self.scripts
        Task { [weak self] in
            let error = await scripts.run(source)
            self?.scriptFinished(error, app: player.rawValue)
            completion(error)
        }
        return true
    }

    private func scriptFinished(_ error: Int?, app: String) {
        guard let error else {
            automationGranted = true
            return
        }
        if error == ScriptRunner.notPermitted {
            automationDenied.insert(app)
            Log.adapter.info("control of \(app, privacy: .public) was not allowed (Automation); using MediaRemote")
        } else {
            Log.adapter.info("AppleScript to \(app, privacy: .public) failed with \(error)")
        }
    }

    // MARK: Stream

    private func launchStream() {
        guard let resources, !isStopping else { return }
        generation += 1
        let current = generation
        let stream = AdapterStream(resources: resources)
        do {
            try stream.start { [weak self] event in
                self?.handle(event, generation: current)
            }
            self.stream = stream
        } catch {
            Log.adapter.error("could not launch the adapter: \(error.localizedDescription, privacy: .public)")
            model.availability = .unavailable("Impossibile avviare /usr/bin/perl: \(error.localizedDescription)")
        }
    }

    private func handle(_ event: AdapterEvent, generation: Int) {
        guard generation == self.generation else { return }
        switch event {
        case .snapshot(let snapshot):
            restartAttempts = 0
            model.availability = .running
            streamUpdated(snapshot)
        case .terminated(let termination):
            stream = nil
            guard !isStopping else { return }
            handleTermination(termination)
        }
    }

    private func handleTermination(_ termination: AdapterTermination) {
        Log.adapter.error("stream exited (status \(termination.status), fatal: \(termination.isFatal))")
        streamUpdated(nil)

        if termination.isFatal {
            let detail = termination.lastError ?? "codice di uscita \(termination.status)"
            model.availability = .unavailable("L'adapter si è fermato: \(detail)")
            return
        }

        restartAttempts += 1
        guard restartAttempts <= Self.maximumRestartAttempts else {
            model.availability = .unavailable("L'adapter continua a chiudersi; riavvia Halo.")
            return
        }
        model.availability = .starting
        let delay = Duration.seconds(1 << (restartAttempts - 1))
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.launchStream()
        }
    }

    // MARK: Model updates

    private func streamUpdated(_ snapshot: NowPlayingSnapshot?) {
        streamSnapshot = snapshot
        if let snapshot {
            if !scriptsPrewarmed, ScriptablePlayer(bundleIdentifier: snapshot.sourceBundleIdentifier) != nil {
                scriptsPrewarmed = true
                scripts.prewarm()
            }
            let (action, confirmed) = reconciler.streamReported(
                playing: snapshot.isPlaying,
                now: Date(),
                routes: playbackRoutes()
            )
            if let confirmed {
                Log.adapter.info("\(confirmed.rawValue, privacy: .public) changed the play state of \(snapshot.sourceBundleIdentifier ?? "?", privacy: .public)")
                attemptTask?.cancel()
                remember(confirmed, worked: true)
            }
            perform(action)
        }
        refreshDisplay()
    }

    /// The stream's state, with the play state the user asked for while it is pursued.
    private func refreshDisplay() {
        guard var shown = streamSnapshot else {
            apply(nil)
            return
        }
        if let desired = reconciler.desired, let optimistic, optimistic.title == shown.title {
            shown.isPlaying = desired
            if let timeline = optimistic.timeline {
                shown.timeline = timeline
            }
        }
        apply(shown)
    }

    private func apply(_ snapshot: NowPlayingSnapshot?) {
        let previous = model.snapshot
        guard snapshot != previous else { return }
        model.snapshot = snapshot
        if snapshot?.artwork != previous?.artwork {
            updateArtwork(snapshot?.artwork)
        }
        if snapshot?.sourceBundleIdentifier != previous?.sourceBundleIdentifier {
            model.sourceIcon = Self.icon(forApplication: snapshot?.sourceBundleIdentifier)
        }
    }

    /// Decodes and analyzes artwork off the main actor. The previous image stays on screen
    /// until the new one is ready, so a track change never flashes the placeholder.
    private func updateArtwork(_ artwork: ArtworkPayload?) {
        artworkTask?.cancel()
        guard let artwork else {
            model.artworkImage = nil
            model.palette = .neutral
            return
        }

        let data = artwork.data
        let id = artwork.id
        artworkTask = Task { [weak self] in
            let decoded = await Task.detached(priority: .userInitiated) {
                ArtworkDecoder.decode(data)
            }.value
            guard let self, !Task.isCancelled, self.model.snapshot?.artwork?.id == id else { return }
            self.model.artworkImage = decoded.map { NSImage(cgImage: $0.image, size: .zero) }
            self.model.palette = decoded?.palette ?? .neutral
        }
    }

    private static func icon(forApplication bundleIdentifier: String?) -> NSImage? {
        guard
            let bundleIdentifier,
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
