/// One scroll event, reduced to what the gesture logic needs (AppKit-free, so it is
/// testable).
struct ScrollSample: Sendable, Equatable {
    enum Phase: Sendable, Equatable {
        /// Fingers touched the trackpad: a new gesture starts.
        case began
        case changed
        /// Fingers lifted (or the gesture was cancelled).
        case ended
        /// No phase: a classic mouse wheel.
        case none
    }

    var deltaX: Double
    var deltaY: Double
    var phase: Phase
    /// Inertial scrolling after the fingers lifted.
    var isMomentum: Bool
    /// Pixel-precise deltas (trackpad, Magic Mouse) rather than wheel lines.
    var isPrecise: Bool
    /// "Natural" scrolling: deltas follow the content, not the fingers.
    var isInverted: Bool
}

/// Turns scrolling over the island into player gestures: a horizontal swipe skips a track
/// (once per swipe: left = next, right = previous), a vertical swipe or a wheel changes the
/// volume (fingers or wheel up = louder), whatever the "natural scrolling" setting.
/// Over an alert, a swipe up instead pushes it back into the notch, as on iPhone.
///
/// Each swipe locks to one axis after a few points of travel, so a slightly diagonal
/// swipe does not do both. Momentum is ignored, so the volume stops with the fingers.
struct ScrollGestureInterpreter {
    enum Action: Sendable, Equatable {
        case nextTrack
        case previousTrack
        /// Change of volume in 0...1 units.
        case volume(Double)
        /// Swipe up over an alert: dismiss it.
        case dismiss
    }

    private enum Axis {
        case horizontal
        case vertical
    }

    /// Travel before the axis is decided.
    static let lockDistance = 6.0
    /// Horizontal travel that skips a track.
    static let skipDistance = 60.0
    /// Upward travel that dismisses an alert.
    static let dismissDistance = 30.0
    /// Full volume range over ~220 points of finger travel.
    static let volumePerPoint = 1.0 / 220
    /// One wheel notch = one system volume step.
    static let volumePerLine = 1.0 / 16

    private var axis: Axis?
    private var travelX = 0.0
    private var travelY = 0.0
    /// The swipe already skipped a track or dismissed an alert: once per swipe.
    private var didAct = false

    /// `swipeUpDismisses`: the island shows an alert, so vertical swipes dismiss it rather
    /// than change the volume.
    mutating func handle(_ sample: ScrollSample, allowsTrackSkip: Bool, swipeUpDismisses: Bool = false) -> Action? {
        guard !sample.isMomentum else { return nil }

        // Movement of the fingers (or wheel): right and up are positive.
        let fingerX = sample.isInverted ? sample.deltaX : -sample.deltaX
        let fingerY = sample.isInverted ? -sample.deltaY : sample.deltaY

        guard sample.isPrecise, sample.phase != .none else {
            guard fingerY != 0, abs(fingerY) >= abs(fingerX) else { return nil }
            if swipeUpDismisses {
                return fingerY > 0 ? .dismiss : nil
            }
            return .volume(fingerY > 0 ? Self.volumePerLine : -Self.volumePerLine)
        }

        switch sample.phase {
        case .began:
            reset()
        case .ended:
            reset()
            return nil
        case .changed, .none:
            break
        }

        travelX += fingerX
        travelY += fingerY
        if axis == nil {
            guard max(abs(travelX), abs(travelY)) >= Self.lockDistance else { return nil }
            axis = abs(travelX) > abs(travelY) ? .horizontal : .vertical
        }

        switch axis {
        case .horizontal:
            guard allowsTrackSkip, !didAct, abs(travelX) >= Self.skipDistance else { return nil }
            didAct = true
            return travelX < 0 ? .nextTrack : .previousTrack
        case .vertical:
            if swipeUpDismisses {
                guard !didAct, travelY >= Self.dismissDistance else { return nil }
                didAct = true
                return .dismiss
            }
            return fingerY == 0 ? nil : .volume(fingerY * Self.volumePerPoint)
        case nil:
            return nil
        }
    }

    private mutating func reset() {
        axis = nil
        travelX = 0
        travelY = 0
        didAct = false
    }
}
