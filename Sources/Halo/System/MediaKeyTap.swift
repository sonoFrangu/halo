import AppKit
import CoreGraphics

/// Intercepts the brightness, volume and mute keys so Halo can replace the system HUD.
///
/// These keys arrive as `NX_SYSDEFINED` events (subtype 8, "aux control buttons") whose
/// `data1` packs the key code and state. An active `CGEventTap` sees them before the
/// system does; returning `nil` swallows the event, so neither the system HUD nor the
/// system's own adjustment happens and Halo applies the change itself. Requires the
/// Accessibility permission. The tap is event driven: it runs only when a key is pressed.
@MainActor
final class MediaKeyTap {
    enum Key: Sendable, Hashable {
        case brightnessUp
        case brightnessDown
        case volumeUp
        case volumeDown
        case mute

        /// Key codes from IOKit's `ev_keymap.h` (`NX_KEYTYPE_*`).
        init?(code: Int) {
            switch code {
            case 0: self = .volumeUp
            case 1: self = .volumeDown
            case 2: self = .brightnessUp
            case 3: self = .brightnessDown
            case 7: self = .mute
            default: return nil
            }
        }
    }

    struct Press: Sendable {
        let key: Key
        let isRepeat: Bool
        /// Option+Shift held: quarter steps, as in macOS.
        let isFine: Bool
    }

    /// Returns `true` when Halo handled the press and the event must be swallowed.
    private let onPress: (Press) -> Bool
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    /// Keys whose key-down was swallowed; their key-up is swallowed too.
    private var swallowed: Set<Key> = []

    private static let systemDefinedEventType: UInt32 = 14  // NX_SYSDEFINED
    private static let auxControlButtonsSubtype: Int16 = 8  // NX_SUBTYPE_AUX_CONTROL_BUTTONS

    init(onPress: @escaping (Press) -> Bool) {
        self.onPress = onPress
    }

    var isRunning: Bool {
        tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false
    }

    /// Installs the tap. Fails (returns `false`) without the Accessibility permission.
    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let mask = CGEventMask(1) << CGEventMask(Self.systemDefinedEventType)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mediaKeyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Log.hud.error("could not create the media key event tap (Accessibility permission missing?)")
            return false
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        Log.hud.info("media key tap installed")
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
        swallowed.removeAll()
    }

    /// Called on the main run loop for every intercepted event.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // The system disables slow or interrupted taps; turn it back on.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        guard
            type.rawValue == Self.systemDefinedEventType,
            let nsEvent = NSEvent(cgEvent: event),
            nsEvent.subtype.rawValue == Self.auxControlButtonsSubtype
        else {
            return false
        }

        let data1 = nsEvent.data1
        guard let key = Key(code: (data1 & 0xFFFF_0000) >> 16) else { return false }
        let flags = data1 & 0x0000_FFFF
        let isKeyDown = ((flags & 0xFF00) >> 8) == 0x0A

        guard isKeyDown else {
            return swallowed.remove(key) != nil
        }
        let press = Press(
            key: key,
            isRepeat: flags & 0x1 == 1,
            isFine: nsEvent.modifierFlags.contains([.option, .shift])
        )
        let handled = onPress(press)
        if handled {
            swallowed.insert(key)
        }
        return handled
    }
}

/// What the C callback hands to the main actor.
///
/// `@unchecked Sendable`: the tap's run loop source is on the main run loop, so the callback
/// runs on the main thread and these values never actually cross threads; the box only
/// tells the compiler so.
private struct MediaKeyTapCallbackContext: @unchecked Sendable {
    let tap: UnsafeMutableRawPointer
    let event: CGEvent
}

/// C callback of the event tap (always on the main thread, see above).
private func mediaKeyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let context = MediaKeyTapCallbackContext(tap: userInfo, event: event)
    let swallow = MainActor.assumeIsolated {
        Unmanaged<MediaKeyTap>.fromOpaque(context.tap)
            .takeUnretainedValue()
            .handle(type: type, event: context.event)
    }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
