import AppKit
import ApplicationServices

/// Media keys, with their `NX_KEYTYPE_*` codes from IOKit's `ev_keymap.h` (the skip keys
/// are the ones a Mac keyboard sends).
enum MediaKey: Int, Sendable {
    case playPause = 16
    case next = 19
    case previous = 20
}

/// Presses a media key on the user's behalf, exactly as the keyboard does: the system
/// routes it to the app that is playing, whatever it is. Posting events needs the
/// Accessibility permission. Play/pause is a toggle, so the controller presses it only
/// when the stream shows the player in the other state and nothing else is in flight.
@MainActor
enum MediaKeyPoster {
    /// `false` without the Accessibility permission (the key would not be delivered).
    static func press(_ key: MediaKey) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        for isDown in [true, false] {
            let state = isDown ? 0xA : 0xB
            guard let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,  // NX_SUBTYPE_AUX_CONTROL_BUTTONS
                data1: (key.rawValue << 16) | (state << 8),
                data2: -1
            ) else { return false }
            event.cgEvent?.post(tap: .cghidEventTap)
        }
        return true
    }
}
