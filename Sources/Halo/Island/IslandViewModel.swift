import AppKit
import Observation
import SwiftUI

/// Decides which shape the island takes: an ongoing drag keeps the current shape, then the
/// brightness/volume HUD, then hover, then playback activity, else idle.
///
/// Inputs are pushed in (pointer positions, playback changes, geometry); state changes are
/// wrapped in the matching spring so every view derived from `state` animates together.
@MainActor
@Observable
final class IslandViewModel {
    private(set) var state: IslandState = .idle
    private(set) var geometry: NotchGeometry
    /// Mirrors the player, but changes inside an animation so the shape morphs smoothly
    /// when media appears or disappears.
    private(set) var hasMedia = false
    /// Pointer over the progress bar (it thickens). Kept here instead of view `@State`,
    /// which Command Line Tools builds cannot expand on the macOS 27 SDK.
    private(set) var isScrubberHovered = false

    var layout: IslandLayout {
        IslandLayout(geometry: geometry)
    }

    /// Called with `true` when the panel should receive mouse events.
    @ObservationIgnored var onInteractivityChange: ((Bool) -> Void)?

    @ObservationIgnored private var isPointerInside = false
    @ObservationIgnored private var isHovering = false
    @ObservationIgnored private var isInteracting = false
    @ObservationIgnored private var showsActivity = false
    @ObservationIgnored private var showsHUD = false
    @ObservationIgnored private var lastInteractivity = false
    @ObservationIgnored private var hoverTask: Task<Void, Never>?
    @ObservationIgnored private var lingerTask: Task<Void, Never>?

    /// Short dwell so sweeping the cursor across the menu bar does not open the island.
    static let expandDelay: Duration = .milliseconds(90)
    /// Forgiveness for brief exits while using the player.
    static let collapseDelay: Duration = .milliseconds(200)
    /// Keeps the compact island through a quick pause/play.
    static let pauseLinger: Duration = .milliseconds(1500)
    static let hoverTolerance: CGFloat = 6

    init(geometry: NotchGeometry) {
        self.geometry = geometry
    }

    // MARK: Inputs

    func updateGeometry(_ geometry: NotchGeometry) {
        guard geometry != self.geometry else { return }
        self.geometry = geometry
    }

    /// `location` is in global AppKit screen coordinates (`NSEvent.mouseLocation`).
    func pointerMoved(to location: CGPoint) {
        let inside = hotZone.contains(location)
        if inside != isPointerInside {
            isPointerInside = inside
            scheduleHover(inside)
        }
        publishInteractivity()
    }

    func playbackChanged(isPlaying: Bool, hasMedia: Bool) {
        if hasMedia != self.hasMedia {
            withAnimation(Motion.shape(from: .compact, to: hasMedia ? .expanded : .compact, reduceMotion: reduceMotion)) {
                self.hasMedia = hasMedia
            }
        }

        if isPlaying && hasMedia {
            lingerTask?.cancel()
            lingerTask = nil
            if !showsActivity {
                showsActivity = true
                resolveState()
            }
        } else if !hasMedia {
            lingerTask?.cancel()
            lingerTask = nil
            showsActivity = false
            resolveState()
        } else if showsActivity && lingerTask == nil {
            lingerTask = Task { [weak self] in
                try? await Task.sleep(for: Self.pauseLinger)
                guard !Task.isCancelled, let self else { return }
                self.lingerTask = nil
                self.showsActivity = false
                self.resolveState()
            }
        }
    }

    func hudChanged(isVisible: Bool) {
        guard isVisible != showsHUD else { return }
        showsHUD = isVisible
        resolveState()
    }

    /// While a bar (progress or HUD level) is dragged the island keeps its shape and stays
    /// interactive even if the cursor leaves it.
    func setInteracting(_ interacting: Bool, pointer location: CGPoint) {
        guard interacting != isInteracting else { return }
        isInteracting = interacting
        if !interacting {
            isPointerInside = hotZone.contains(location)
            scheduleHover(isPointerInside)
            resolveState()
        }
        publishInteractivity()
    }

    func setScrubberHovered(_ hovered: Bool) {
        guard hovered != isScrubberHovered else { return }
        isScrubberHovered = hovered
    }

    // MARK: State

    private var hotZone: CGRect {
        let spec = layout.spec(for: state, hasMedia: hasMedia)
        let body = geometry.islandRect(width: spec.width, height: spec.height)
        return body.insetBy(dx: -(spec.earRadius + Self.hoverTolerance), dy: -Self.hoverTolerance)
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func scheduleHover(_ inside: Bool) {
        hoverTask?.cancel()
        let delay = inside ? Self.expandDelay : Self.collapseDelay
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.isHovering = inside
            self.resolveState()
        }
    }

    private func resolveState() {
        let target: IslandState
        if isInteracting && (state == .expanded || state == .hud) {
            target = state
        } else if showsHUD {
            target = .hud
        } else if isHovering {
            target = .expanded
        } else if showsActivity {
            target = .compact
        } else {
            target = .idle
        }
        guard target != state else { return }

        withAnimation(Motion.shape(from: state, to: target, reduceMotion: reduceMotion)) {
            state = target
        }
        if target != .expanded {
            // The panel turns click-through when collapsing, so no hover-exit may arrive.
            isScrubberHovered = false
        }
        publishInteractivity()
    }

    private func publishInteractivity() {
        let isOpen = state == .expanded || state == .hud
        let interactive = isOpen && (isPointerInside || isInteracting)
        guard interactive != lastInteractivity else { return }
        lastInteractivity = interactive
        onInteractivityChange?(interactive)
    }
}
