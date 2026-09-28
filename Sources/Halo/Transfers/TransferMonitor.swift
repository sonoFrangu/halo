import AppKit
import Observation

/// Downloads and AirDrops arriving in Downloads, as a live activity: progress in the
/// island's wings while they run, a banner when they finish.
///
/// Browsers and AirDrop publish the progress of the file they write (that is how Finder
/// draws progress bars on files). Halo subscribes to the Downloads folder with
/// `Progress.addSubscriber(forFileURL:)` and observes each progress with KVO; updates are
/// thinned to whole percents before they reach the main actor. Nothing runs while no
/// transfer is in flight.
@MainActor
@Observable
final class TransferMonitor {
    private(set) var transfers: [Transfer] = []
    private(set) var isEnabled = Preferences.transfersEnabled

    /// The newest transfer still running.
    var current: Transfer? {
        transfers.last
    }

    @ObservationIgnored private let alerts: AlertCenter
    @ObservationIgnored private let shelf: ShelfStore
    @ObservationIgnored private var subscription: Any?
    @ObservationIgnored private var folder: URL?

    init(alerts: AlertCenter, shelf: ShelfStore) {
        self.alerts = alerts
        self.shelf = shelf
    }

    // MARK: Finished files

    /// Opens the file; if it moved (a browser may still be renaming it), its folder.
    func open(_ url: URL) {
        NSWorkspace.shared.open(Self.exists(url) ? url : url.deletingLastPathComponent())
    }

    func reveal(_ url: URL) {
        if Self.exists(url) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url.deletingLastPathComponent())
        }
        alerts.dismissCurrent()
    }

    func keepOnShelf(_ url: URL) {
        guard Self.exists(url) else { return }
        shelf.add([url])
        Haptics.perform(.action)
        alerts.dismissCurrent()
    }

    private static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func start() {
        guard
            isEnabled,
            subscription == nil,
            let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        else { return }
        self.folder = folder
        let sink = TransferSink { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event)
            }
        }
        subscription = Self.subscribe(to: folder, sink: sink)
    }

    func stop() {
        if let subscription {
            Progress.removeSubscriber(subscription)
        }
        subscription = nil
        transfers.removeAll()
        alerts.withdraw(.transfer)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.transfersEnabled = enabled
        if enabled { start() } else { stop() }
    }

    private func handle(_ event: TransferEvent) {
        switch event {
        case .began(let transfer):
            transfers.removeAll { $0.id == transfer.id }
            transfers.append(transfer)
        case .progressed(let id, let fraction):
            guard let index = transfers.firstIndex(where: { $0.id == id }) else { return }
            transfers[index].fraction = fraction
        case .ended(let id, let completed):
            guard let index = transfers.firstIndex(where: { $0.id == id }) else { return }
            let transfer = transfers.remove(at: index)
            if completed, let folder {
                let url = folder.appendingPathComponent(transfer.name)
                alerts.post(.transfer(TransferAlert(name: transfer.name, kind: transfer.kind, url: url)))
            }
        }
    }

    // MARK: Subscription

    // Nonisolated on purpose: Foundation calls these closures on its own queues, so they
    // must not inherit the main actor's isolation. Only Sendable values leave them.

    private nonisolated static func subscribe(to folder: URL, sink: TransferSink) -> Any {
        Progress.addSubscriber(forFileURL: folder) { progress in
            observe(progress, sink: sink)
        }
    }

    private nonisolated static func observe(_ progress: Progress, sink: TransferSink) -> Progress.UnpublishingHandler? {
        guard let url = progress.fileURL else { return nil }
        let operation = progress.fileOperationKind
        let kind: Transfer.Kind
        if operation == .receiving {
            kind = .airDrop
        } else if operation == .downloading || TransferNaming.isPartial(url) {
            kind = .download
        } else {
            return nil
        }

        let id = UUID()
        let gate = FractionGate()
        let fraction = progress.fractionCompleted
        _ = gate.admit(fraction)
        sink.send(.began(Transfer(id: id, name: TransferNaming.displayName(for: url), kind: kind, fraction: fraction)))

        let observation = progress.observe(\.fractionCompleted, options: [.new]) { progress, _ in
            let fraction = progress.fractionCompleted
            if gate.admit(fraction) {
                sink.send(.progressed(id, fraction))
            }
        }
        let tracked = TrackedProgress(progress: progress, observation: observation)
        return {
            sink.send(.ended(id, completed: tracked.finish()))
        }
    }
}

enum TransferEvent: Sendable {
    case began(Transfer)
    case progressed(UUID, Double)
    case ended(UUID, completed: Bool)
}

/// Hands events from Foundation's queues to the main actor.
struct TransferSink: Sendable {
    let send: @Sendable (TransferEvent) -> Void
}

/// Lets a fraction through when it moved by a whole percent, or reached the end.
final class FractionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var last = -1.0

    func admit(_ fraction: Double) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let reachedEnd = fraction >= 1 && last < 1
        guard reachedEnd || abs(fraction - last) >= 0.01 else { return false }
        last = fraction
        return true
    }
}

/// A published progress and its KVO observation, kept for the unpublishing handler.
final class TrackedProgress: @unchecked Sendable {
    private let progress: Progress
    private let observation: NSKeyValueObservation

    init(progress: Progress, observation: NSKeyValueObservation) {
        self.progress = progress
        self.observation = observation
    }

    /// Stops observing; returns whether the transfer completed (rather than being cancelled).
    func finish() -> Bool {
        observation.invalidate()
        return !progress.isCancelled && (progress.isFinished || progress.fractionCompleted >= 0.999)
    }
}
