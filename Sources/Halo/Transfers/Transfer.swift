import Foundation

/// A file on its way into Downloads: a browser download or an AirDrop.
struct Transfer: Sendable, Equatable, Identifiable {
    enum Kind: Sendable, Equatable {
        case download
        case airDrop
    }

    let id: UUID
    var name: String
    var kind: Kind
    /// 0...1.
    var fraction: Double
}

enum TransferNaming {
    /// Suffixes browsers give files still being downloaded.
    static let partialSuffixes = [".download", ".crdownload", ".part", ".partial"]

    /// The file's final name: "Report.pdf.download" → "Report.pdf".
    static func displayName(for url: URL) -> String {
        var name = url.lastPathComponent
        for suffix in partialSuffixes where name.lowercased().hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
            break
        }
        return name
    }

    static func isPartial(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        return partialSuffixes.contains { name.hasSuffix($0) }
    }
}
