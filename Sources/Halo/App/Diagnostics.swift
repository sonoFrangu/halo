import AppKit
import ApplicationServices
import Observation
import os

/// A short, readable record of what Halo just did (clicks, commands, what the player
/// reported), shown in Settings › Informazioni with a button that copies it: problems
/// that only happen on a real Mac can be reported without the Terminal. Every entry also
/// goes to the unified log at the default level, so `log stream` shows it.
@MainActor
@Observable
final class Diagnostics {
    static let shared = Diagnostics()

    struct Entry: Identifiable, Equatable {
        let id: Int
        let date: Date
        let text: String
    }

    private(set) var entries: [Entry] = []
    @ObservationIgnored private var counter = 0

    static let limit = 80

    func record(_ text: String) {
        counter += 1
        entries.append(Entry(id: counter, date: Date(), text: text))
        if entries.count > Self.limit {
            entries.removeFirst(entries.count - Self.limit)
        }
        Log.app.notice("\(text, privacy: .public)")
    }

    /// Which build is running: version, commit and time of `scripts/bundle.sh`.
    static var build: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let stamp = Bundle.main.object(forInfoDictionaryKey: "HaloBuild") as? String ?? "build sconosciuta"
        return "\(version) (\(stamp))"
    }

    /// Everything, as plain text for the clipboard.
    var report: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        var lines = [
            "Halo \(Self.build)",
            "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Accessibilità: \(AXIsProcessTrusted() ? "concessa" : "non concessa")",
            "",
        ]
        lines += entries.map { "\(formatter.string(from: $0.date))  \($0.text)" }
        return lines.joined(separator: "\n")
    }

    func copyReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
    }
}
