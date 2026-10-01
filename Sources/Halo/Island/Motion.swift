import SwiftUI

/// Animation vocabulary for the island. Opening is springy with a restrained bounce;
/// closing is shorter and damped so the island gets out of the way quickly. With
/// Reduce Motion everything becomes a brief ease without bounce, blur or scale.
enum Motion {
    static func shape(from old: IslandState, to new: IslandState, reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return .easeInOut(duration: 0.18)
        }
        return .spring(isOpening(from: old, to: new) ? opening : closing)
    }

    static let opening = Spring(duration: 0.5, bounce: 0.24)
    /// Barely bouncy: closing into the notch must not swing back out from behind it
    /// (`NotchShapeTests`).
    static let closing = Spring(duration: 0.34, bounce: 0.08)

    /// Size changes within a state (media appears, an alert changes style, a tab switches).
    static func context(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.18) : .spring(duration: 0.45, bounce: 0.16)
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

    /// Shadow and halo arrive once the opening spring has nearly settled, so they are never
    /// re-blurred on a moving outline.
    static func decorationIn(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.3).delay(0.28)
    }

    static var decorationOut: Animation { .easeOut(duration: 0.1) }

    // Roles for changes inside the island's content, the widgets and banners: the same
    // kind of change moves the same way everywhere.

    /// A level, percentage or progress moving: smooth, no bounce.
    static var value: Animation { .smooth(duration: 0.3) }
    /// Content replaced in place (a title, the artwork, the weather, the time): a soft
    /// crossfade.
    static var content: Animation { .easeInOut(duration: 0.25) }
    /// Items appearing, moving or reordering inside a view: smooth, no bounce.
    static var layout: Animation { .smooth(duration: 0.4) }
    /// Something opening or arriving (a widget, a panel, the unlocked padlock): the only
    /// content motion with a small bounce, like the island's own opening.
    static var appear: Animation { .spring(duration: 0.5, bounce: 0.15) }

    static var hoverFeedback: Animation { .spring(duration: 0.25, bounce: 0.3) }
    static var press: Animation { .spring(duration: 0.2, bounce: 0.45) }
    static var palette: Animation { .easeInOut(duration: 0.6) }

    private static func isOpening(from old: IslandState, to new: IslandState) -> Bool {
        rank(new) > rank(old)
    }

    private static func rank(_ state: IslandState) -> Int {
        switch state {
        case .idle: 0
        case .compact, .alert: 1
        case .expanded: 2
        }
    }
}
