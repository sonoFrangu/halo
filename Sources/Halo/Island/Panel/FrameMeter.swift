import AppKit
import QuartzCore

/// Counts the frames of each island animation, to check it keeps the display's rate.
///
/// Off by default; `defaults write io.github.sonofrangu.halo measureFrames -bool true` and
/// a relaunch turn it on. Each change of shape then logs (category "island") how many
/// frames came, how many were late and the longest gap. A display link on the main thread
/// is the right clock here: SwiftUI computes every frame of the island's springs there.
@MainActor
final class FrameMeter: NSObject {
    static let isEnabled = UserDefaults.standard.bool(forKey: "measureFrames")
    /// Long enough for the opening spring and the staggered reveal after it.
    static let window: Duration = .milliseconds(900)

    private var link: CADisplayLink?
    private var stopTask: Task<Void, Never>?
    private var label = ""
    private var lastTimestamp: CFTimeInterval?
    private var frameDuration: CFTimeInterval = 1.0 / 60
    private var frames = 0
    private var dropped = 0
    private var longestGap: CFTimeInterval = 0

    func measure(_ label: String, in view: NSView) {
        guard Self.isEnabled else { return }
        finish()
        self.label = label
        let link = view.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: Self.window)
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        frameDuration = link.targetTimestamp - link.timestamp
        if let lastTimestamp {
            let gap = link.timestamp - lastTimestamp
            frames += 1
            longestGap = max(longestGap, gap)
            // A gap of two frames or more means frames were skipped.
            let missed = Int((gap / frameDuration).rounded()) - 1
            dropped += max(missed, 0)
        }
        lastTimestamp = link.timestamp
    }

    /// Logs the animation measured so far (a new one may interrupt it) and stops.
    private func finish() {
        stopTask?.cancel()
        guard let link else { return }
        link.invalidate()
        self.link = nil
        let rate = Int((1 / frameDuration).rounded())
        let gap = Int((longestGap * 1000).rounded())
        Log.island.notice("frames \(self.label, privacy: .public): \(self.frames) at \(rate) Hz, \(self.dropped) dropped, longest gap \(gap) ms")
        lastTimestamp = nil
        frames = 0
        dropped = 0
        longestGap = 0
    }
}
