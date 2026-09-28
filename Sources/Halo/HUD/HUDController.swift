import Foundation

/// Replaces the system brightness and volume HUD: intercepts the keys, applies the change
/// itself (DisplayServices, CoreAudio) and posts it to the island as the `.hud` alert.
@MainActor
final class HUDController {
    enum Status: Equatable {
        case disabled
        case needsPermission
        case active
    }

    let model = HUDModel()
    private(set) var status: Status = .disabled

    private let alerts: AlertCenter
    private let brightness = DisplayBrightness()
    private let volume: SystemVolume
    private let permission = AccessibilityPermission()
    private lazy var keyTap = MediaKeyTap { [weak self] press in
        self?.handle(press) ?? false
    }

    init(alerts: AlertCenter, volume: SystemVolume) {
        self.alerts = alerts
        self.volume = volume
    }

    func start() {
        permission.observeChanges { [weak self] in
            self?.refresh(prompt: false)
        }
        refresh(prompt: !Preferences.hasAskedForAccessibility)
    }

    func stop() {
        keyTap.stop()
    }

    var isEnabled: Bool {
        Preferences.hudReplacementEnabled
    }

    func setEnabled(_ enabled: Bool) {
        Preferences.hudReplacementEnabled = enabled
        refresh(prompt: enabled)
    }

    /// Shows the system Accessibility prompt again (from the menu).
    func requestPermission() {
        permission.request()
    }

    // MARK: HUD interaction (dragging the level bar)

    /// Sets the level of whatever the HUD shows; keeps the HUD up while dragging.
    func setLevel(_ level: Double) {
        alerts.post(.hud)
        let level = min(max(level, 0), 1)
        switch model.kind {
        case .brightness:
            if brightness.setLevel(level) {
                model.level = level
            }
        case .volume:
            if model.isMuted && level > 0, volume.setMuted(false) {
                model.isMuted = false
            }
            if volume.setLevel(level) {
                model.level = level
            }
        }
    }

    // MARK: Keys

    private func refresh(prompt: Bool) {
        guard Preferences.hudReplacementEnabled else {
            keyTap.stop()
            status = .disabled
            return
        }
        if permission.isGranted, keyTap.start() {
            status = .active
            return
        }
        keyTap.stop()
        status = .needsPermission
        if prompt {
            Preferences.hasAskedForAccessibility = true
            permission.request()
        }
    }

    /// Returns `true` when the key was handled (and must not reach the system).
    private func handle(_ press: MediaKeyTap.Press) -> Bool {
        switch press.key {
        case .brightnessUp, .brightnessDown:
            guard let current = brightness.level() else { return false }
            let target = HUDStep.next(from: current, up: press.key == .brightnessUp, fine: press.isFine)
            guard brightness.setLevel(target) else { return false }
            present(.brightness, level: target, muted: false)
            return true

        case .volumeUp, .volumeDown:
            guard let current = volume.level() else { return false }
            let up = press.key == .volumeUp
            if up && volume.isMuted() {
                volume.setMuted(false)
            }
            let target = HUDStep.next(from: current, up: up, fine: press.isFine)
            guard volume.setLevel(target) else { return false }
            present(.volume, level: target, muted: volume.isMuted())
            return true

        case .mute:
            guard let current = volume.level() else { return false }
            let muted = !volume.isMuted()
            guard volume.setMuted(muted) else { return false }
            present(.volume, level: current, muted: muted)
            return true
        }
    }

    private func present(_ kind: HUDKind, level: Double, muted: Bool) {
        model.kind = kind
        model.level = level
        model.isMuted = muted
        if kind == .volume {
            model.route = volume.route
        }
        alerts.post(.hud)
    }
}
