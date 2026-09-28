import AppKit

/// Notices when the user is dragging files anywhere on screen, so the click-through island
/// can become a drop target when the drag reaches the notch.
///
/// Starting a drag writes to the drag pasteboard; a global monitor of left-button events
/// (which needs no permission) compares its change count while the button is down with the
/// value recorded when the button was last released. Event driven: nothing runs unless the
/// mouse button is used.
@MainActor
final class FileDragMonitor {
    private let onChange: (Bool) -> Void
    private var monitors: [Any] = []
    private var baselineChangeCount = NSPasteboard(name: .drag).changeCount
    private(set) var isDraggingFiles = false

    init(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
    }

    func start() {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated {
                self?.mouseButtonActivity()
            }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated {
                self?.mouseButtonActivity()
            }
            return event
        }) {
            monitors.append(local)
        }
    }

    func stop() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
        set(false)
    }

    private func mouseButtonActivity() {
        let pasteboard = NSPasteboard(name: .drag)
        let isButtonDown = NSEvent.pressedMouseButtons & 1 != 0
        guard isButtonDown else {
            baselineChangeCount = pasteboard.changeCount
            set(false)
            return
        }
        guard !isDraggingFiles, pasteboard.changeCount != baselineChangeCount else { return }
        let hasFiles = pasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
        if hasFiles {
            set(true)
        }
    }

    private func set(_ dragging: Bool) {
        guard dragging != isDraggingFiles else { return }
        isDraggingFiles = dragging
        onChange(dragging)
    }
}
