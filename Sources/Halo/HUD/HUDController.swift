import Foundation

/// Replaces the system brightness and volume HUD: intercepts the keys, applies the change
/// itself (DisplayServices, CoreAudio) and presents it in the island.
@MainActor
final class HUDController {
    enum Status: Equatable {
        case disabled
        case needsPermission
        case active
    }

    let model = HUDModel()
    private(set) var status: Status = .disabled

    /// How long the HUD stays after the last change.
    static let visibleDuration: Duration = .milliseconds(1600)

    private let brightness = DisplayBrightness()
    private let volume = SystemVolume()
    private let permission = AccessibilityPermission()
    private lazy var keyTap = MediaKeyTap { [weak self] press in
        self?.handle(press) ?? false
    }
    private var hideTask: Task<Void, Never>?
    private var isInteracting = false

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

    func setLevel(_ level: Double) {
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

    func setInteracting(_ interacting: Bool) {
        isInteracting = interacting
        if interacting {
            hideTask?.cancel()
        } else {
            scheduleHide()
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
        model.isVisible = true
        scheduleHide()
    }

    private func scheduleHide() {
        hideTask?.cancel()
        guard !isInteracting else { return }
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.visibleDuration)
            guard !Task.isCancelled else { return }
            self?.model.isVisible = false
        }
    }
}
