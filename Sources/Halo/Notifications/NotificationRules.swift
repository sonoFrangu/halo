import Foundation

/// How an app's notifications appear in the notch, chosen per app in Settings › Avvisi.
enum NotificationAppMode: String, CaseIterable, Sendable {
    /// The whole banner: sender, message and photo.
    case show
    /// Only the app's icon and name, for apps whose content should not show on screen.
    case appOnly
    /// Not in the notch at all (the system banner still appears).
    case hidden
}

enum NotificationDecision: Equatable, Sendable {
    case drop
    case full
    case appOnly
}

/// Whether one notification reaches the notch, and how.
enum NotificationRules {
    nonisolated static func decide(
        bundleIdentifier: String,
        ownBundleIdentifier: String?,
        mode: NotificationAppMode,
        focusSilencing: Bool,
        bypassesFocus: Bool
    ) -> NotificationDecision {
        if bundleIdentifier == ownBundleIdentifier
            || NotificationMirror.isFromWebsite(bundleIdentifier)
            || NotificationMirror.isFromBluetooth(bundleIdentifier) {
            return .drop
        }
        if mode == .hidden || (focusSilencing && !bypassesFocus) {
            return .drop
        }
        return mode == .appOnly ? .appOnly : .full
    }
}
