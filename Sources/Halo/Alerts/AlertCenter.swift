import Foundation
import Observation

/// Decides which alert the island shows and for how long.
///
/// - Alerts of the same kind replace each other (a new HUD level, a newer notification);
///   notifications from the same app stack and keep count (`IslandAlert.replacing`).
/// - The HUD preempts anything: it is direct feedback to a key press. An alert it
///   interrupts goes back to the front of the queue and gets its full time afterwards.
/// - Other alerts queue up and are shown one after another.
/// - Dismissal pauses while something holds it: a drag on the HUD bar, the pointer resting
///   on a banner, or an expanded island (where banners would otherwise expire unseen).
/// - While quiet (a full-screen app is in front), alerts that would only interrupt are
///   dropped; direct feedback (HUD, keyboard), timers, meetings and low battery still show.
@MainActor
@Observable
final class AlertCenter {
    private(set) var current: IslandAlert?
    @ObservationIgnored var isQuiet = false

    @ObservationIgnored private var queue: [IslandAlert] = []
    @ObservationIgnored private var dismissTask: Task<Void, Never>?
    /// Holders that pause every alert, including the HUD.
    @ObservationIgnored private var interactionHolders: Set<String> = []
    /// Holders that pause banners and charging alerts but not the HUD.
    @ObservationIgnored private var readingHolders: Set<String> = []

    func post(_ alert: IslandAlert) {
        guard !(isQuiet && alert.waitsOutPresentations) else { return }
        if let current {
            if current.kind == alert.kind {
                self.current = alert.replacing(current)
            } else if alert.kind == .hud {
                queue.insert(current, at: 0)
                self.current = alert
            } else {
                let queued = queue.first { $0.kind == alert.kind }
                queue.removeAll { $0.kind == alert.kind }
                queue.append(queued.map(alert.replacing) ?? alert)
                return
            }
        } else {
            current = alert
        }
        scheduleDismiss()
    }

    /// Dismisses the visible alert now (e.g. after a click).
    func dismissCurrent() {
        advance()
    }

    /// Removes queued and visible alerts of a kind (e.g. when a feature is turned off).
    func withdraw(_ kind: IslandAlert.Kind) {
        queue.removeAll { $0.kind == kind }
        if current?.kind == kind {
            advance()
        }
    }

    /// While held by an interaction (dragging the HUD bar) nothing is dismissed.
    func setInteracting(_ interacting: Bool, by holder: String) {
        if Self.update(&interactionHolders, interacting, holder) {
            scheduleDismiss()
        }
    }

    /// While held for reading (pointer on a banner, island expanded) alerts other than the
    /// HUD stay.
    func setReading(_ reading: Bool, by holder: String) {
        if Self.update(&readingHolders, reading, holder) {
            scheduleDismiss()
        }
    }

    // MARK: Private

    /// Returns whether the set changed. Static, so the `inout` access to the property ends
    /// before `scheduleDismiss` reads the holders again (exclusivity).
    private static func update(_ holders: inout Set<String>, _ held: Bool, _ holder: String) -> Bool {
        held ? holders.insert(holder).inserted : holders.remove(holder) != nil
    }

    private func isHeld(_ alert: IslandAlert) -> Bool {
        if !interactionHolders.isEmpty { return true }
        return alert.kind != .hud && !readingHolders.isEmpty
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        guard let current, !isHeld(current) else { return }
        let duration = current.duration
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.advance()
        }
    }

    private func advance() {
        dismissTask?.cancel()
        current = queue.isEmpty ? nil : queue.removeFirst()
        scheduleDismiss()
    }
}
