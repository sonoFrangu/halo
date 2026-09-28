import AppKit
import Observation

/// A file stashed on the shelf. The shelf keeps references, not copies: moving or
/// deleting the original removes it from the shelf.
struct ShelfItem: Sendable, Identifiable, Equatable {
    let url: URL

    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

/// Files dropped onto the notch, persisted across launches.
@MainActor
@Observable
final class ShelfStore {
    private(set) var items: [ShelfItem] = []

    static let limit = 24
    private static let defaultsKey = "shelfPaths"

    init() {
        let paths = UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? []
        items = paths
            .map { ShelfItem(url: URL(fileURLWithPath: $0)) }
            .filter { FileManager.default.fileExists(atPath: $0.url.path) }
    }

    var isEmpty: Bool { items.isEmpty }

    func add(_ urls: [URL]) {
        var changed = false
        for url in urls where url.isFileURL {
            let item = ShelfItem(url: url.standardizedFileURL)
            guard !items.contains(item) else { continue }
            items.insert(item, at: 0)
            changed = true
        }
        if items.count > Self.limit {
            items.removeLast(items.count - Self.limit)
        }
        if changed { save() }
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0 == item }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    func open(_ item: ShelfItem) {
        NSWorkspace.shared.open(item.url)
    }

    func reveal(_ item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    /// Drops items whose file disappeared (moved, deleted, ejected).
    func prune() {
        let existing = items.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        if existing.count != items.count {
            items = existing
            save()
        }
    }

    private func save() {
        UserDefaults.standard.set(items.map(\.url.path), forKey: Self.defaultsKey)
    }
}
