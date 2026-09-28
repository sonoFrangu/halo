import AppKit

/// Owns the adapter processes and keeps `NowPlayingModel` in sync with them.
@MainActor
final class NowPlayingController {
    let model: NowPlayingModel

    private static let maximumRestartAttempts = 3
    /// How long the optimistic play/pause state wins over contradicting stream updates.
    static let optimisticHold: TimeInterval = 2.5
    /// How long an in-process play/pause may take to show up in the stream.
    static let confirmationTimeout: Duration = .milliseconds(900)

    /// Where commands go: MediaRemote in-process (`unverified` until a play/pause is
    /// confirmed, `direct` after) or the adapter.
    private enum Route {
        case unverified
        case direct
        case adapter
    }

    /// A play/pause the stream has not confirmed yet.
    private struct PendingPlayback {
        let isPlaying: Bool
        let deadline: Date
    }

    private var resources: AdapterResources?
    private var stream: AdapterStream?
    private var commands: AdapterCommandRunner?
    private let direct = DirectMediaRemote()
    private var route = Route.unverified
    private var pendingPlayback: PendingPlayback?
    private var confirmationTask: Task<Void, Never>?
    /// Distinguishes events of the current stream from a previous, already replaced one.
    private var generation = 0
    private var isStopping = false
    private var restartAttempts = 0
    private var restartTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?

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
        confirmationTask?.cancel()
        stream?.stop()
        stream = nil
        commands?.shutdown()
    }

    // MARK: Controls

    /// Asks for the opposite of what is on screen with an explicit play or pause. A toggle
    /// could undo itself: clicking again while the player's state was still on its way
    /// flipped playback back.
    func togglePlayPause() {
        guard let snapshot = model.snapshot else { return }
        let playing = !snapshot.isPlaying
        let now = Date()
        model.snapshot = snapshot.settingPlaying(playing, at: now)
        pendingPlayback = PendingPlayback(isPlaying: playing, deadline: now.addingTimeInterval(Self.optimisticHold))
        deliverPlayback(playing)
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
        if route == .direct, direct.seek(to: position) {
            return
        }
        commands?.seek(to: position)
    }

    /// Play/pause go straight through MediaRemote unless that already failed once. Each is
    /// then confirmed by the stream: without confirmation in time the adapter sends it
    /// again (play and pause are idempotent, so a late duplicate is harmless) and every
    /// later command uses the adapter.
    private func deliverPlayback(_ playing: Bool) {
        let command: MediaCommand = playing ? .play : .pause
        confirmationTask?.cancel()
        confirmationTask = nil
        guard route != .adapter, direct.send(command) else {
            route = .adapter
            commands?.send(command)
            return
        }
        confirmationTask = Task { [weak self] in
            try? await Task.sleep(for: Self.confirmationTimeout)
            guard !Task.isCancelled, let self else { return }
            self.confirmationTask = nil
            guard let pending = self.pendingPlayback else { return }
            Log.adapter.info("in-process MediaRemote command had no effect; switching to the adapter")
            self.route = .adapter
            self.commands?.send(pending.isPlaying ? .play : .pause)
        }
    }

    /// Track skips cannot be confirmed safely ("previous" may just restart the track), so
    /// they go in-process only once a play/pause has proved that route.
    private func send(_ command: MediaCommand) {
        if route == .direct, direct.send(command) {
            return
        }
        commands?.send(command)
    }

    /// Brings the playing app to the front (Safari for a YouTube tab).
    func openSourceApp() {
        guard
            let identifier = model.snapshot?.sourceBundleIdentifier,
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
        else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
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
            apply(reconciled(snapshot))
        case .terminated(let termination):
            stream = nil
            guard !isStopping else { return }
            handleTermination(termination)
        }
    }

    private func handleTermination(_ termination: AdapterTermination) {
        Log.adapter.error("stream exited (status \(termination.status), fatal: \(termination.isFatal))")
        apply(nil)

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

    /// Keeps the optimistic play/pause state against stream updates that predate the
    /// command (the button no longer flips back and forth), and takes the matching update
    /// as the confirmation that proves the in-process route.
    private func reconciled(_ incoming: NowPlayingSnapshot?) -> NowPlayingSnapshot? {
        guard let pending = pendingPlayback, var incoming else { return incoming }
        if incoming.isPlaying == pending.isPlaying {
            pendingPlayback = nil
            if let confirmationTask {
                confirmationTask.cancel()
                self.confirmationTask = nil
                if route == .unverified {
                    route = .direct
                }
            }
            return incoming
        }
        guard Date() < pending.deadline, incoming.title == model.snapshot?.title else {
            pendingPlayback = nil
            return incoming
        }
        incoming.isPlaying = pending.isPlaying
        if let optimistic = model.snapshot?.timeline {
            incoming.timeline = optimistic
        }
        return incoming
    }

    private func apply(_ snapshot: NowPlayingSnapshot?) {
        let previous = model.snapshot
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
