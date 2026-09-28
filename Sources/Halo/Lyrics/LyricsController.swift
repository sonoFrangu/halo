import Foundation
import Observation

/// Lyrics of the current track, for the UI.
@MainActor
@Observable
final class LyricsModel {
    enum Status: Equatable {
        case none
        case loading
        case synced
        case unavailable
    }

    private(set) var status: Status = .none
    private(set) var lines: [LyricLine] = []
    /// The user wants the lyrics panel (toggled from the player).
    private(set) var isPanelEnabled = Preferences.showsLyrics

    func setPanelEnabled(_ enabled: Bool) {
        isPanelEnabled = enabled
        Preferences.showsLyrics = enabled
    }

    /// The panel is shown only when the user wants it and the track has synced lyrics.
    var showsPanel: Bool {
        isPanelEnabled && status == .synced && !lines.isEmpty
    }

    fileprivate func update(status: Status, lines: [LyricLine]) {
        self.status = status
        self.lines = lines
    }
}

/// Fetches synced lyrics whenever the track changes. Event driven: it reacts to Now
/// Playing changes (through Observation), debounces rapid skips, and caches results.
@MainActor
final class LyricsController {
    let model = LyricsModel()

    private let player: NowPlayingModel
    private var currentQuery: LyricsQuery?
    private var fetchTask: Task<Void, Never>?
    private var cache: [LyricsQuery: LyricsResult] = [:]
    private var cacheOrder: [LyricsQuery] = []
    private var isRunning = false

    static let debounce: Duration = .milliseconds(350)
    static let cacheLimit = 60

    init(player: NowPlayingModel) {
        self.player = player
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        observeTrack()
    }

    func stop() {
        isRunning = false
        fetchTask?.cancel()
        currentQuery = nil
        model.update(status: .none, lines: [])
    }

    private func observeTrack() {
        guard isRunning else { return }
        let query = withObservationTracking {
            Self.query(for: player.snapshot)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeTrack()
            }
        }
        trackChanged(query)
    }

    private static func query(for snapshot: NowPlayingSnapshot?) -> LyricsQuery? {
        guard let snapshot, let artist = snapshot.artist, !artist.isEmpty else { return nil }
        return LyricsQuery(
            title: snapshot.title,
            artist: artist,
            album: snapshot.album,
            duration: snapshot.timeline.map { Int($0.duration.rounded()) }
        )
    }

    private func trackChanged(_ query: LyricsQuery?) {
        guard query != currentQuery else { return }
        currentQuery = query
        fetchTask?.cancel()

        guard let query else {
            model.update(status: .none, lines: [])
            return
        }
        if let cached = cache[query] {
            apply(cached)
            return
        }

        model.update(status: .loading, lines: [])
        fetchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            let result: LyricsResult
            do {
                result = try await LyricsService.lyrics(for: query)
            } catch {
                guard !Task.isCancelled else { return }
                Log.app.info("lyrics lookup failed: \(error.localizedDescription, privacy: .public)")
                self?.model.update(status: .unavailable, lines: [])
                return
            }
            guard !Task.isCancelled, let self, self.currentQuery == query else { return }
            self.remember(result, for: query)
            self.apply(result)
        }
    }

    private func apply(_ result: LyricsResult) {
        switch result {
        case .synced(let lines):
            model.update(status: .synced, lines: lines)
        case .plainOnly, .notFound:
            model.update(status: .unavailable, lines: [])
        }
    }

    private func remember(_ result: LyricsResult, for query: LyricsQuery) {
        cache[query] = result
        cacheOrder.append(query)
        if cacheOrder.count > Self.cacheLimit {
            cache.removeValue(forKey: cacheOrder.removeFirst())
        }
    }
}
