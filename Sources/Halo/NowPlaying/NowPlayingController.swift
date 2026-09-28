import AppKit

/// Owns the adapter processes and keeps `NowPlayingModel` in sync with them.
@MainActor
final class NowPlayingController {
    let model: NowPlayingModel

    private static let maximumRestartAttempts = 3

    private var resources: AdapterResources?
    private var stream: AdapterStream?
    private var commands: AdapterCommandRunner?
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
        stream?.stop()
        stream = nil
        commands?.shutdown()
    }

    // MARK: Controls

    func togglePlayPause() {
        guard let snapshot = model.snapshot else { return }
        model.snapshot = snapshot.settingPlaying(!snapshot.isPlaying, at: Date())
        commands?.send(.togglePlayPause)
    }

    func nextTrack() {
        commands?.send(.nextTrack)
    }

    func previousTrack() {
        commands?.send(.previousTrack)
    }

    func seek(to position: TimeInterval) {
        if let snapshot = model.snapshot {
            model.snapshot = snapshot.seeking(to: position, at: Date())
        }
        commands?.seek(to: position)
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
            apply(snapshot)
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
