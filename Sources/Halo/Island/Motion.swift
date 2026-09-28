import SwiftUI

/// Animation vocabulary for the island. Opening is springy with a restrained bounce;
/// closing is shorter and damped so the island gets out of the way quickly. With
/// Reduce Motion everything becomes a brief ease without bounce, blur or scale.
enum Motion {
    static func shape(from old: IslandState, to new: IslandState, reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return .easeInOut(duration: 0.18)
        }
        return isOpening(from: old, to: new)
            ? .spring(duration: 0.5, bounce: 0.24)
            : .spring(duration: 0.34, bounce: 0.08)
    }

    /// Staggered content reveal: waits for the shape to open, then fades in one element
    /// after another. Hiding is immediate and quick.
    static func reveal(isVisible: Bool, order: Int, reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return .easeInOut(duration: 0.15)
        }
        guard isVisible else {
            return .easeOut(duration: 0.12)
        }
        return .spring(duration: 0.42, bounce: 0.16).delay(0.1 + 0.04 * Double(order))
    }

    static var hoverFeedback: Animation { .spring(duration: 0.25, bounce: 0.3) }
    static var press: Animation { .spring(duration: 0.2, bounce: 0.45) }
    static var palette: Animation { .easeInOut(duration: 0.6) }

    private static func isOpening(from old: IslandState, to new: IslandState) -> Bool {
        rank(new) > rank(old)
    }

    private static func rank(_ state: IslandState) -> Int {
        switch state {
        case .idle: 0
        case .compact: 1
        case .expanded: 2
        }
    }
}
