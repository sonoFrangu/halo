import Foundation

/// Calls back when Notification Center writes to its database, using kqueue vnode events on
/// the database, its write-ahead log and their folder (which reports the log being created
/// or removed). Nothing runs between writes; the writes of a burst are coalesced into one
/// callback a moment after the first of them.
@MainActor
final class DatabaseChangeWatcher {
    private let databaseURL: URL
    private let onChange: () -> Void
    private var sources: [DispatchSourceFileSystemObject] = []
    private var pending: Task<Void, Never>?

    /// Wait after the first write of a burst. Writes during the wait do not extend it:
    /// usernoted keeps writing while notifications pour in, and a wait restarted by each
    /// write held every banner back until the stream stopped, seconds later.
    static let coalescing: Duration = .milliseconds(120)

    init(databaseURL: URL, onChange: @escaping () -> Void) {
        self.databaseURL = databaseURL
        self.onChange = onChange
    }

    func start() {
        arm()
    }

    func stop() {
        pending?.cancel()
        pending = nil
        disarm()
    }

    private var watchedURLs: [URL] {
        [
            databaseURL.deletingLastPathComponent(),
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-wal"),
        ]
    }

    private func arm() {
        disarm()
        for url in watchedURLs {
            watch(url)
        }
    }

    private func watch(_ url: URL) {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename, .revoke],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.changed()
            }
        }
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()
        sources.append(source)
    }

    private func disarm() {
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
    }

    private func changed() {
        guard pending == nil else { return }
        pending = Task { [weak self] in
            try? await Task.sleep(for: Self.coalescing)
            guard !Task.isCancelled, let self else { return }
            self.pending = nil
            // The log may have been created, replaced or removed: follow the current files.
            self.arm()
            self.onChange()
        }
    }
}
