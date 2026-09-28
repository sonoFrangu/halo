import Foundation

/// Why the long-lived `stream` process stopped.
struct AdapterTermination: Sendable {
    let status: Int32
    let reason: Process.TerminationReason
    let lastError: String?

    /// The adapter asks not to be re-invoked after a fatal error (non-zero exit code).
    var isFatal: Bool {
        reason == .exit && status != 0
    }
}

enum AdapterEvent: Sendable {
    case snapshot(NowPlayingSnapshot?)
    case terminated(AdapterTermination)
}

/// Runs `mediaremote-adapter.pl … stream` and forwards decoded snapshots.
///
/// Event driven end to end: the pipe's `readabilityHandler` feeds an `AsyncStream`, a
/// single detached task frames lines and decodes JSON off the main thread, and results
/// hop to the main actor through `onEvent`. Ordering is preserved because there is
/// exactly one producer and one consumer.
@MainActor
final class AdapterStream {
    private let resources: AdapterResources
    private var process: Process?
    private var consumer: Task<Void, Never>?

    init(resources: AdapterResources) {
        self.resources = resources
    }

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    func start(onEvent: @escaping @Sendable @MainActor (AdapterEvent) -> Void) throws {
        stop()

        let process = Process()
        process.executableURL = resources.perl
        process.arguments = resources.arguments(["stream", "--micros", "--debounce=40"])
        process.standardInput = FileHandle.nullDevice

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let (chunks, chunkContinuation) = AsyncStream.makeStream(of: Data.self)
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                chunkContinuation.finish()
            } else {
                chunkContinuation.yield(data)
            }
        }

        let stderrTail = StderrTail()
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                stderrTail.append(data)
            }
        }

        let (exits, exitContinuation) = AsyncStream.makeStream(of: (Int32, Process.TerminationReason).self)
        process.terminationHandler = { finished in
            exitContinuation.yield((finished.terminationStatus, finished.terminationReason))
            exitContinuation.finish()
        }

        try process.run()
        self.process = process
        Log.adapter.info("stream started (pid \(process.processIdentifier))")

        consumer = Task.detached(priority: .utility) {
            var splitter = LineSplitter()
            var decoder = NowPlayingStreamDecoder()
            for await chunk in chunks {
                for line in splitter.append(chunk) {
                    if case .update(let snapshot) = decoder.decode(line: line) {
                        await onEvent(.snapshot(snapshot))
                    }
                }
            }
            // stdout reached EOF: the process is exiting; wait for its status.
            var status: Int32 = -1
            var reason = Process.TerminationReason.exit
            for await exit in exits {
                (status, reason) = exit
            }
            let termination = AdapterTermination(status: status, reason: reason, lastError: stderrTail.line)
            await onEvent(.terminated(termination))
        }
    }

    /// Sends SIGTERM, which the adapter handles by leaving its run loop.
    func stop() {
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        consumer = nil
    }
}
