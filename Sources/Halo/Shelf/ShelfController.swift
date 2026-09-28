import AppKit
import Observation

/// The file shelf: its store, thumbnails and the global file-drag detection.
@MainActor
@Observable
final class ShelfController {
    let store = ShelfStore()
    let thumbnails = ShelfThumbnails()
    private(set) var isEnabled = Preferences.shelfEnabled

    @ObservationIgnored private var dragMonitor: FileDragMonitor?
    /// Tells the islands a file drag started or ended.
    @ObservationIgnored var onFileDragChange: ((Bool) -> Void)?

    func start() {
        guard isEnabled, dragMonitor == nil else { return }
        store.prune()
        let monitor = FileDragMonitor { [weak self] dragging in
            self?.onFileDragChange?(dragging)
        }
        monitor.start()
        dragMonitor = monitor
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.shelfEnabled = enabled
        if enabled {
            start()
        } else {
            dragMonitor?.stop()
            dragMonitor = nil
        }
    }

    /// Adds the files behind dropped item providers.
    func drop(_ providers: [NSItemProvider]) {
        let store = self.store
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    store.add([url])
                }
            }
        }
    }
}
