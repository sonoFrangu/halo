import AppKit

/// Reports the pointer while it drags files, which the islands' own tracking areas cannot
/// see: the drag belongs to the app the files come from.
///
/// Plain movement comes from each island panel's tracking area, which fires even while
/// the panel is click-through, and only near the notch. A global monitor of mouse moves
/// would make the window server send Halo every move on every screen, which cost about 3 %
/// of a core while the mouse moved. Dragged events are monitored only during a file drag.
@MainActor
final class PointerMonitor {
    private let onMove: () -> Void
    private var monitors: [Any] = []

    init(onMove: @escaping () -> Void) {
        self.onMove = onMove
    }

    /// Follows the pointer from the start of a file drag until it ends.
    func setFollowsDrag(_ follows: Bool) {
        guard follows != !monitors.isEmpty else { return }
        guard follows else {
            invalidate()
            return
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged, handler: { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onMove()
            }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged, handler: { [weak self] event in
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
