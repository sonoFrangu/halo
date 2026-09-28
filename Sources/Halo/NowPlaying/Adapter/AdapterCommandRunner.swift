import Foundation

/// Runs short-lived adapter commands (`send`, `seek`) strictly in the order they were
/// requested: rapid "next, next, previous" must reach the player in that order, so a
/// single worker drains a queue and waits for each process to exit before the next.
@MainActor
final class AdapterCommandRunner {
    private let queue: AsyncStream<[String]>.Continuation
    private let worker: Task<Void, Never>

    init(resources: AdapterResources) {
        let (commands, queue) = AsyncStream.makeStream(of: [String].self)
        self.queue = queue
        worker = Task.detached(priority: .userInitiated) {
            for await command in commands {
                await Self.run(command, resources: resources)
            }
        }
    }

    func send(_ command: MediaCommand) {
        queue.yield(["send", String(command.rawValue)])
    }

    /// Seeks to an absolute position; the adapter expects microseconds.
    func seek(to position: TimeInterval) {
        let micros = Int64((max(0, position) * 1_000_000).rounded())
        queue.yield(["seek", String(micros)])
    }

    func shutdown() {
        queue.finish()
        worker.cancel()
    }

    private nonisolated static func run(_ command: [String], resources: AdapterResources) async {
        let process = Process()
        process.executableURL = resources.perl
        process.arguments = resources.arguments(command)
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let status: Int32? = await withCheckedContinuation { continuation in
            process.terminationHandler = { finished in
                continuation.resume(returning: finished.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                Log.adapter.error("could not launch adapter command: \(error.localizedDescription, privacy: .public)")
                continuation.resume(returning: nil)
            }
        }

        if let status, status != 0 {
            let description = command.joined(separator: " ")
            Log.adapter.error("adapter command '\(description, privacy: .public)' exited with \(status)")
        }
    }
}
