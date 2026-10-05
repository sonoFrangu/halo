import Foundation

/// What the island plays when the Mac is unlocked.
enum UnlockAnimationStyle: String {
    /// The padlock springing open, as on iPhone.
    case padlock
    /// The Face ID sequence: face, spinning rings, checkmark.
    case faceID
}

/// Plays the iOS unlock moment: when the Mac is unlocked the island briefly shows a
/// padlock springing open or the Face ID sequence. Driven by the system's distributed
/// notification.
@MainActor
final class UnlockGreeter {
    private(set) var isEnabled = Preferences.unlockAnimationEnabled
    private let alerts: AlertCenter
    private var observer: NSObjectProtocol?

    private static let unlockedNotification = Notification.Name("com.apple.screenIsUnlocked")

    init(alerts: AlertCenter) {
        self.alerts = alerts
    }

    func start() {
        guard isEnabled, observer == nil else { return }
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Self.unlockedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.alerts.post(.unlock(Preferences.unlockAnimationStyle))
            }
        }
    }

    func stop() {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observer = nil
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.unlockAnimationEnabled = enabled
        if enabled { start() } else { stop() }
    }
}
