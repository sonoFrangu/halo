import AppKit

/// Keeps one island per display (or only on the notched/primary one) in sync with the
/// display configuration, and fans pointer movement out to all of them.
@MainActor
final class IslandsCoordinator {
    private let services: IslandServices
    private var islands: [CGDirectDisplayID: IslandController] = [:]
    private var screenTracker: ScreenTracker?
    private var pointerMonitor: PointerMonitor?

    init(services: IslandServices) {
        self.services = services
        screenTracker = ScreenTracker { [weak self] in
            self?.rebuild()
        }
        pointerMonitor = PointerMonitor { [weak self] in
            self?.pointerMoved()
        }
        services.shelf.onFileDragChange = { [weak self] dragging in
            self?.fileDragChanged(dragging)
        }
        rebuild()
    }

    /// Re-reads the display list; called on configuration changes and preference changes.
    func rebuild() {
        let screens = Preferences.showsOnAllDisplays
            ? NSScreen.screens
            : [ScreenTracker.preferredScreen()].compactMap { $0 }

        var next: [CGDirectDisplayID: IslandController] = [:]
        for screen in screens {
            guard let id = screen.displayID else { continue }
            if let existing = islands[id] {
                existing.update(screen: screen)
                next[id] = existing
            } else {
                next[id] = IslandController(screen: screen, displayID: id, services: services)
            }
        }
        for (id, island) in islands where next[id] == nil {
            island.close()
        }
        islands = next
    }

    private func pointerMoved() {
        let location = NSEvent.mouseLocation
        for island in islands.values {
            island.pointerMoved(to: location)
        }
    }

    private func fileDragChanged(_ dragging: Bool) {
        for island in islands.values {
            island.fileDragChanged(dragging)
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
