import AppKit
import Observation

/// Music and lyrics on the lock screen: while the Mac is locked and something is playing, a
/// Now Playing card is shown over the lock screen (see `LockScreenSpace`).
///
/// Event driven: it follows the system's lock and unlock notifications and the player's
/// state. It works on the lock screen of a signed-in user; the login window after a restart
/// runs before any user app, so nothing can be shown there.
@MainActor
final class LockScreenController {
    private let player: NowPlayingModel
    private let lyrics: LyricsModel
    private let actions: PlayerActions
    private let card = CardState()
    private var panel: CardPanel?
    private var space: LockScreenSpace?
    private var spaceUnavailable = false
    private var observers: [NSObjectProtocol] = []
    private var isLocked = false
    private var isRunning = false
    private(set) var isEnabled = Preferences.lockScreenEnabled

    static let size = CGSize(
        width: PlayerWidgetView.Metrics.lockScreen.width + 2 * LockScreenView.shadowMargin,
        height: 460
    )
    /// Vertical position of the card's top, as a fraction of the screen height from the
    /// top: below the lock screen clock, above the user picture.
    static let topFraction: CGFloat = 0.34

    init(player: NowPlayingModel, lyrics: LyricsModel, actions: PlayerActions) {
        self.player = player
        self.lyrics = lyrics
        self.actions = actions
    }

    func start() {
        guard isEnabled, !isRunning else { return }
        isRunning = true
        let center = DistributedNotificationCenter.default()
        observers = [
            center.addObserver(forName: Self.lockedNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.lockChanged(true)
                }
            },
            center.addObserver(forName: Self.unlockedNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.lockChanged(false)
                }
            },
        ]
        observePlayback()
    }

    func stop() {
        isRunning = false
        let center = DistributedNotificationCenter.default()
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
        hide()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.lockScreenEnabled = enabled
        if enabled { start() } else { stop() }
    }

    private static let lockedNotification = Notification.Name("com.apple.screenIsLocked")
    private static let unlockedNotification = Notification.Name("com.apple.screenIsUnlocked")

    private func lockChanged(_ locked: Bool) {
        isLocked = locked
        update()
    }

    /// Re-arms on every change, like the island's observers: no polling.
    private func observePlayback() {
        guard isRunning else { return }
        let player = self.player
        _ = withObservationTracking {
            player.hasMedia
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observePlayback()
            }
        }
        update()
    }

    private func update() {
        if isRunning && isLocked && player.hasMedia {
            show()
        } else {
            hide()
        }
    }

    private func show() {
        guard let screen = NSScreen.screens.first else { return }
        if space == nil && !spaceUnavailable {
            space = LockScreenSpace()
            spaceUnavailable = space == nil
        }
        guard let space else { return }

        let panel = self.panel ?? makePanel()
        self.panel = panel
        let frame = screen.frame
        panel.setFrameOrigin(CGPoint(
            x: frame.midX - Self.size.width / 2,
            y: frame.maxY - frame.height * Self.topFraction - Self.size.height + LockScreenView.shadowMargin
        ))
        panel.orderFrontRegardless()
        space.add(panel)
        // One frame hidden first, so the card animates in.
        Task { @MainActor [weak self] in
            self?.card.setVisible(true)
        }
    }

    private func hide() {
        card.setVisible(false)
        panel?.orderOut(nil)
    }

    private func makePanel() -> CardPanel {
        let panel = CardPanel.make(
            size: Self.size,
            level: NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow))),
            behavior: [.stationary, .ignoresCycle, .fullScreenAuxiliary]
        )
        panel.contentView = CardHostingView(
            rootView: LockScreenView(player: player, lyrics: lyrics, card: card, actions: actions)
        )
        return panel
    }
}
