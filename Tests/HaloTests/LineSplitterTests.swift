import Foundation
import Testing
@testable import Halo

struct LineSplitterTests {
    private func feed(_ splitter: inout LineSplitter, _ text: String) -> [String] {
        splitter.append(Data(text.utf8)).map { String(decoding: $0, as: UTF8.self) }
    }

    @Test func splitsCompleteLines() {
        var splitter = LineSplitter()
        let lines = feed(&splitter, "a\nbb\n")
        #expect(lines == ["a", "bb"])
    }

    @Test func keepsPartialLineUntilNewline() {
        var splitter = LineSplitter()
        let first = feed(&splitter, "{\"ty")
        let second = feed(&splitter, "pe\":1")
        let third = feed(&splitter, "}\nnext")
        let fourth = feed(&splitter, "\n")
        #expect(first.isEmpty)
        #expect(second.isEmpty)
        #expect(third == ["{\"type\":1}"])
        #expect(fourth == ["next"])
    }

    @Test func dropsEmptyLines() {
        var splitter = LineSplitter()
        let lines = feed(&splitter, "\n\nx\n\n")
        #expect(lines == ["x"])
    }

    @Test func handlesLargeLinesAcrossManyChunks() {
        var splitter = LineSplitter()
        let bytes = Data((String(repeating: "A", count: 300_000) + "\n").utf8)
        var produced: [Data] = []
        var offset = 0
        while offset < bytes.count {
            let end = min(offset + 65_536, bytes.count)
            produced += splitter.append(bytes.subdata(in: offset..<end))
            offset = end
        }
        #expect(produced.count == 1)
        #expect(produced.first?.count == 300_000)
    }

    @Test func doesNotSplitOnUnicodeLineSeparators() {
        var splitter = LineSplitter()
        let line = "{\"title\":\"a\u{2028}b\"}"
        let lines = feed(&splitter, line + "\n")
        #expect(lines == [line])
    }
}
