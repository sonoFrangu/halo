import Foundation
import Synchronization

/// Keeps the last non-empty line the adapter printed to stderr, to explain failures.
/// Written from the pipe's reader thread, read on the main actor.
final class StderrTail: Sendable {
    private let lastLine = Mutex<String?>(nil)

    func append(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        let lines = text.split(whereSeparator: \.isNewline)
        guard let last = lines.last(where: { !$0.allSatisfy(\.isWhitespace) }) else { return }
        let line = String(last)
        Log.adapter.debug("adapter stderr: \(line, privacy: .public)")
        lastLine.withLock { $0 = line }
    }

    var line: String? {
        lastLine.withLock { $0 }
    }
}
