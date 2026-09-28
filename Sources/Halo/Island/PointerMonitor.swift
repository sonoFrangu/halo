import AppKit

/// Reports mouse movement anywhere on screen without stealing events.
///
/// While the panel is click-through it receives no events of its own, so a global monitor
/// (events delivered to other apps) and a local monitor (events delivered to Halo) cover
/// every case. Monitoring mouse events, unlike key events, needs no Accessibility
/// permission. This is event driven: nothing runs while the mouse is still.
@MainActor
final class PointerMonitor {
    private let onMove: () -> Void
    private var monitors: [Any] = []

    init(onMove: @escaping () -> Void) {
        self.onMove = onMove
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]

        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onMove()
            }
        }) {
            monitors.append(global)
        }

        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated {
                self?.onMove()
            }
            return event
        }) {
            monitors.append(local)
        }
    }

    func invalidate() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
    }
}
