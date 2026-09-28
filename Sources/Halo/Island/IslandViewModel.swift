import AppKit
import Observation
import SwiftUI

/// Decides which shape the island takes for one screen.
///
/// Priority: an ongoing drag keeps the current shape; an open island stays open (alerts
/// wait, the HUD shows inline); files dragged to the notch open the shelf; then alerts;
/// then hover; then playback; else idle.
/// Inputs are pushed in (pointer positions, playback, alerts, geometry); every change of
/// `state` or `context` happens inside a spring so shape and content animate together.
@MainActor
@Observable
final class IslandViewModel {
    private(set) var state: IslandState = .idle
    private(set) var geometry: NotchGeometry
    private(set) var context = IslandContext()
    /// The alert being shown, if any.
    private(set) var alert: IslandAlert?
    /// The last alert shown, kept so content can fade out with its payload.
    private(set) var displayedAlert: IslandAlert?
    /// Pointer over the progress bar (it thickens). Kept here instead of view `@State`,
    /// which Command Line Tools builds cannot expand on the macOS 27 SDK.
    private(set) var isScrubberHovered = false
    /// Tabs of the expanded island; the player is always first.
    private(set) var availableTabs: [ExpandedTab] = [.player]
    /// A file drag is over the shelf.
    private(set) var isDropTargeted = false

    var layout: IslandLayout {
        IslandLayout(geometry: geometry)
    }

    var hasMedia: Bool {
        context.hasMedia
    }

    /// Swipes can skip tracks: the player is open on screen.
    var acceptsTrackGestures: Bool {
        state == .expanded && context.tab == .player && context.hasMedia
    }

    /// Scrolling changes the volume: over the open player or over the volume HUD.
    var acceptsVolumeGestures: Bool {
        (state == .expanded && context.tab == .player) || (state == .alert && alert == .hud)
    }

    /// Called with `true` when the panel should receive mouse events.
    @ObservationIgnored var onInteractivityChange: ((Bool) -> Void)?
    /// Called with `true` while alerts should wait (player open, pointer on a banner).
    @ObservationIgnored var onHoldsAlertsChange: ((Bool) -> Void)?
    /// Called when the island opens (`true`) or closes (`false`).
    @ObservationIgnored var onExpandedChange: ((Bool) -> Void)?

    @ObservationIgnored private var isPointerInside = false
    @ObservationIgnored private var isHovering = false
    @ObservationIgnored private var isInteracting = false
    @ObservationIgnored private var showsActivity = false
    @ObservationIgnored private var isDraggingFiles = false
    @ObservationIgnored private var lastInteractivity = false
    @ObservationIgnored private var lastHoldsAlerts = false
    @ObservationIgnored private var hoverTask: Task<Void, Never>?
    @ObservationIgnored private var lingerTask: Task<Void, Never>?

    /// Short dwell so sweeping the cursor across the menu bar does not open the island
    /// (adjustable in Settings).
    static var expandDelay: Duration {
        .milliseconds(Int((Preferences.hoverDelay * 1000).rounded()))
    }
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
        publish()
    }

    func playbackChanged(isPlaying: Bool, hasMedia: Bool) {
        updateContext { $0.hasMedia = hasMedia }

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

    func alertChanged(_ alert: IslandAlert?) {
        guard alert != self.alert else { return }
        withAnimation(Motion.context(reduceMotion: reduceMotion)) {
            self.alert = alert
            if let alert {
                displayedAlert = alert
                context.alertStyle = alert.style
            }
        }
        resolveState()
    }

    func selectTab(_ tab: ExpandedTab) {
        guard availableTabs.contains(tab) else { return }
        updateContext { $0.tab = tab }
    }

    func lyricsChanged(visible: Bool) {
        updateContext { $0.showsLyrics = visible }
    }

    func tabsChanged(_ tabs: [ExpandedTab]) {
        let tabs = [ExpandedTab.player] + tabs.filter { $0 != .player }
        guard tabs != availableTabs else { return }
        withAnimation(Motion.context(reduceMotion: reduceMotion)) {
            availableTabs = tabs
        }
        if !tabs.contains(context.tab) {
            updateContext { $0.tab = .player }
        }
    }

    private var isShelfAvailable: Bool {
        availableTabs.contains(.shelf)
    }

    /// Files are being dragged somewhere on screen: reaching the notch opens the shelf.
    func fileDragChanged(_ dragging: Bool) {
        guard dragging != isDraggingFiles else { return }
        isDraggingFiles = dragging && isShelfAvailable
        if !dragging {
            setDropTargeted(false)
        }
        resolveState()
    }

    func setDropTargeted(_ targeted: Bool) {
        guard targeted != isDropTargeted else { return }
        isDropTargeted = targeted
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
        publish()
    }

    func setScrubberHovered(_ hovered: Bool) {
        guard hovered != isScrubberHovered else { return }
        isScrubberHovered = hovered
    }

    // MARK: State

    private var hotZone: CGRect {
        let spec = layout.spec(for: state, context: context)
        let body = geometry.islandRect(width: spec.width, height: spec.height)
        return body.insetBy(dx: -(spec.earRadius + Self.hoverTolerance), dy: -Self.hoverTolerance)
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func updateContext(_ change: (inout IslandContext) -> Void) {
        var next = context
        change(&next)
        guard next != context else { return }
        withAnimation(Motion.context(reduceMotion: reduceMotion)) {
            context = next
        }
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
        let isOpen = state == .expanded || state == .alert
        let target: IslandState
        if isInteracting && isOpen {
            target = state
        } else if state == .expanded && isHovering {
            target = .expanded
        } else if isDraggingFiles && isHovering {
            target = .expanded
        } else if alert != nil {
            target = .alert
        } else if isHovering {
            target = .expanded
        } else if showsActivity {
            target = .compact
        } else {
            target = .idle
        }
        // A file drag opens (or turns) the island onto the shelf; closing returns to the player.
        let tab: ExpandedTab
        if target == .expanded && isDraggingFiles {
            tab = .shelf
        } else if target != .expanded {
            tab = .player
        } else {
            tab = context.tab
        }
        guard target != state else {
            if tab != context.tab {
                updateContext { $0.tab = tab }
            }
            publish()
            return
        }

        let wasExpanded = state == .expanded
        withAnimation(Motion.shape(from: state, to: target, reduceMotion: reduceMotion)) {
            state = target
            context.tab = tab
        }
        if wasExpanded != (target == .expanded) {
            onExpandedChange?(target == .expanded)
        }
        if target != .expanded {
            // The panel turns click-through when collapsing, so no hover-exit may arrive.
            isScrubberHovered = false
        }
        publish()
    }

    private func publish() {
        let isOpen = state == .expanded || state == .alert
        let interactive = isOpen && (isPointerInside || isInteracting)
        if interactive != lastInteractivity {
            lastInteractivity = interactive
            onInteractivityChange?(interactive)
        }

        let holdsAlerts = state == .expanded || (state == .alert && isPointerInside)
        if holdsAlerts != lastHoldsAlerts {
            lastHoldsAlerts = holdsAlerts
            onHoldsAlertsChange?(holdsAlerts)
        }
    }
}
