import Foundation

/// Reports screenshots and screen recordings as they are saved, through a live Spotlight
/// query (`kMDItemIsScreenCapture`). Spotlight pushes the updates: nothing runs between
/// captures, whatever folder they are saved to.
///
/// macOS writes the file only when its own floating thumbnail goes away (about five
/// seconds), unless that thumbnail is turned off in the Screenshot app's options.
@MainActor
final class ScreenshotWatcher {
    private let onCapture: (URL) -> Void
    private var query: NSMetadataQuery?
    private var observer: NSObjectProtocol?
    private var seen: Set<String> = []

    init(onCapture: @escaping (URL) -> Void) {
        self.onCapture = onCapture
    }

    func start() {
        guard query == nil else { return }
        let query = NSMetadataQuery()
        // Only captures made from now on; older ones are not news.
        query.predicate = NSPredicate(
            format: "kMDItemIsScreenCapture == 1 AND kMDItemContentCreationDate >= %@",
            Date() as NSDate
        )
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        observer = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] notification in
            // Plain paths leave this nonisolated closure, not the notification itself.
            let items = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] ?? []
            let paths = items.compactMap { $0.value(forAttribute: NSMetadataItemPathKey) as? String }
            MainActor.assumeIsolated {
                self?.added(paths)
            }
        }
        query.start()
        self.query = query
    }

    func stop() {
        query?.stop()
        query = nil
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    private func added(_ paths: [String]) {
        for path in paths where seen.insert(path).inserted {
            onCapture(URL(fileURLWithPath: path))
        }
    }
}
