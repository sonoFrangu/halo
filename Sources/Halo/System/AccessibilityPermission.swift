import ApplicationServices
import Foundation

/// The Accessibility permission, needed by the media key tap.
@MainActor
final class AccessibilityPermission {
    private var observer: (any NSObjectProtocol)?
    private var recheckTask: Task<Void, Never>?
    private var onChange: (() -> Void)?

    var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt that leads to Settings › Privacy & Security › Accessibility.
    func request() {
        // The literal value of `kAXTrustedCheckOptionPrompt`; the imported global is a
        // mutable C variable that Swift 6 rejects as not concurrency-safe.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Calls `onChange` when the trusted-apps list changes. The system posts this
    /// distributed notification whenever any app is added to or removed from the list;
    /// the new state becomes readable shortly after, hence the short one-off delay.
    func observeChanges(_ onChange: @escaping () -> Void) {
        self.onChange = onChange
        observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleRecheck()
            }
        }
    }

    private func scheduleRecheck() {
        recheckTask?.cancel()
        recheckTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.onChange?()
        }
    }
}
