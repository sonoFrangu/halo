import AppKit

/// Force Touch trackpad feedback for gestures. It is felt only while a finger rests on the
/// trackpad, which is exactly when a gesture happens; it can be turned off in Settings.
@MainActor
enum Haptics {
    enum Feedback {
        /// A discrete action happened (track skipped, file dropped).
        case action
        /// A limit was reached (volume at 0 or 100 %).
        case limit
        /// A step on a scale (tab changed).
        case step
    }

    static func perform(_ feedback: Feedback) {
        guard Preferences.hapticsEnabled else { return }
        let pattern: NSHapticFeedbackManager.FeedbackPattern
        switch feedback {
        case .action: pattern = .generic
        case .limit: pattern = .alignment
        case .step: pattern = .levelChange
        }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}
