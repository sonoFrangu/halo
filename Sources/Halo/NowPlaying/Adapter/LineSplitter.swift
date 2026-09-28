import Foundation

/// Frames a byte stream into newline-terminated lines.
///
/// The adapter prints one JSON document per line; lines carrying artwork can be several
/// hundred kilobytes and arrive split across many pipe reads. Only `\n` is a separator:
/// JSON never contains a raw newline, whereas generic "lines" APIs also split on Unicode
/// separators that may legitimately appear inside titles.
struct LineSplitter {
    /// Guards against unbounded growth if the stream ever stops producing newlines.
    static let maximumLineLength = 64 * 1024 * 1024

    private var buffer = Data()
    /// Number of bytes at the start of `buffer` already known to contain no newline.
    private var scannedCount = 0

    /// Appends a chunk and returns every line it completed, without the trailing newline.
    /// Empty lines are dropped.
    mutating func append(_ chunk: Data) -> [Data] {
        guard !chunk.isEmpty else { return [] }
        buffer.append(chunk)

        var lines: [Data] = []
        var lineStart = 0
        var cursor = scannedCount
        buffer.withUnsafeBytes { bytes in
            while cursor < bytes.count {
                if bytes[cursor] == 0x0A {
                    if cursor > lineStart {
                        lines.append(Data(bytes[lineStart..<cursor]))
                    }
                    lineStart = cursor + 1
                }
                cursor += 1
            }
        }

        if lineStart > 0 {
            buffer.removeSubrange(buffer.startIndex..<(buffer.startIndex + lineStart))
        }
        scannedCount = buffer.count

        if buffer.count > Self.maximumLineLength {
            buffer.removeAll(keepingCapacity: false)
            scannedCount = 0
        }
        return lines
    }
}
