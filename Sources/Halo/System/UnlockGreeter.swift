import Foundation

/// Plays the iOS unlock moment: when the Mac is unlocked the island briefly shows a
/// padlock springing open. Driven by the system's distributed notification.
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
                self?.alerts.post(.unlock)
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
