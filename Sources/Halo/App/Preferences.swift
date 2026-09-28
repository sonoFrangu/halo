import Foundation

/// Persisted user choices.
@MainActor
enum Preferences {
    private enum Key {
        static let hudReplacement = "hudReplacementEnabled"
        static let askedForAccessibility = "askedForAccessibility"
    }

    private static var defaults: UserDefaults { .standard }

    /// Replace the system brightness and volume HUD with the island. On by default.
    static var hudReplacementEnabled: Bool {
        get { defaults.object(forKey: Key.hudReplacement) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.hudReplacement) }
    }

    /// The Accessibility prompt is shown automatically only once; afterwards it is reachable
    /// from the menu.
    static var hasAskedForAccessibility: Bool {
        get { defaults.bool(forKey: Key.askedForAccessibility) }
        set { defaults.set(newValue, forKey: Key.askedForAccessibility) }
    }
}
