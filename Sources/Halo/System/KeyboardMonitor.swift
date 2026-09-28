import AppKit
import Carbon

/// The keyboard layout in use.
struct InputSource: Sendable, Equatable {
    var id: String
    var name: String
    /// ISO code of its main language ("it", "en"), when it has one.
    var language: String?
}

/// Brief alerts when the keyboard layout changes or Caps Lock toggles.
///
/// The layout change is a system notification (no permission). Caps Lock comes from a
/// monitor of modifier-key events, which macOS only delivers to apps allowed under
/// Accessibility (already needed by the HUD); without it only the layout alert works.
@MainActor
final class KeyboardMonitor {
    private let alerts: AlertCenter
    private var observer: NSObjectProtocol?
    private var monitors: [Any] = []
    private var capsLockOn = NSEvent.modifierFlags.contains(.capsLock)
    private var sourceID: String?
    private(set) var isEnabled = Preferences.keyboardAlertsEnabled

    private static let inputSourceChanged = Notification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged")

    init(alerts: AlertCenter) {
        self.alerts = alerts
    }

    func start() {
        guard isEnabled, observer == nil else { return }
        sourceID = Self.currentInputSource()?.id
        capsLockOn = NSEvent.modifierFlags.contains(.capsLock)

        observer = DistributedNotificationCenter.default().addObserver(
            forName: Self.inputSourceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.layoutChanged()
            }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            let on = event.modifierFlags.contains(.capsLock)
            MainActor.assumeIsolated {
                self?.capsLockChanged(on)
            }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            let on = event.modifierFlags.contains(.capsLock)
            MainActor.assumeIsolated {
                self?.capsLockChanged(on)
            }
            return event
        }) {
            monitors.append(local)
        }
    }

    func stop() {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observer = nil
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
        alerts.withdraw(.keyboard)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.keyboardAlertsEnabled = enabled
        if enabled { start() } else { stop() }
    }

    // MARK: Events

    private func layoutChanged() {
        guard let source = Self.currentInputSource(), source.id != sourceID else { return }
        sourceID = source.id
        alerts.post(.keyboard(.layout(source)))
    }

    private func capsLockChanged(_ on: Bool) {
        guard on != capsLockOn else { return }
        capsLockOn = on
        alerts.post(.keyboard(.capsLock(on: on)))
    }

    // MARK: Text Input Sources

    static func currentInputSource() -> InputSource? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }

        // The property keys are the documented values of the kTISProperty… constants.
        func value<T>(_ key: String, as type: T.Type) -> T? {
            guard let pointer = TISGetInputSourceProperty(source, key as CFString) else { return nil }
            return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? T
        }

        guard let id = value("TISPropertyInputSourceID", as: String.self) else { return nil }
        let name = value("TISPropertyLocalizedName", as: String.self) ?? id
        let languages = value("TISPropertyInputSourceLanguages", as: [String].self)
        return InputSource(id: id, name: name, language: languages?.first)
    }
}
