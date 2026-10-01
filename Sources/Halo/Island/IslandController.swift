import AppKit
import Observation

/// One island on one display: connects pointer movement and the shared services to its
/// view model, and the view model to its panel.
@MainActor
final class IslandController {
    let displayID: CGDirectDisplayID
    private let viewModel: IslandViewModel
    private let services: IslandServices
    private let panelController: IslandPanelController
    private let holderID: String
    private var scrollGesture = ScrollGestureInterpreter()

    init(screen: NSScreen, displayID: CGDirectDisplayID, services: IslandServices) {
        self.displayID = displayID
        self.services = services
        self.holderID = "island-\(displayID)"

        let geometry = NotchGeometry(screen: screen)
        let viewModel = IslandViewModel(geometry: geometry)
        self.viewModel = viewModel
        self.panelController = IslandPanelController(
            rootView: IslandRootView(
                island: viewModel,
                models: IslandModels(
                    player: services.nowPlaying.model,
                    hud: services.hud.model,
                    lyrics: services.lyrics.model,
                    weather: services.weather.model,
                    shelf: services.shelf.store,
                    thumbnails: services.shelf.thumbnails,
                    clipboard: services.clipboard,
                    calendar: services.calendar.model,
                    timers: services.timers,
                    systemTimers: services.systemTimers,
                    transfers: services.transfers,
                    privacy: services.privacy,
                    energy: services.energy
                ),
                actions: Self.actions(for: viewModel, services: services, dragHolder: "hud-drag-\(displayID)")
            )
        )

        viewModel.onInteractivityChange = { [weak self] interactive in
            self?.panelController.setInteractive(interactive)
        }
        viewModel.onHoldsAlertsChange = { [weak self] holds in
            guard let self else { return }
            self.services.alerts.setReading(holds, by: self.holderID)
        }
        viewModel.onExpandedChange = { [weak self] expanded in
            if expanded {
                self?.services.islandDidExpand()
            }
        }
        panelController.onPointerActivity = { [weak self] in
            self?.pointerMoved(to: NSEvent.mouseLocation)
        }
        panelController.onScroll = { [weak self] event in
            self?.scrolled(event) ?? false
        }

        panelController.show(geometry: geometry, layout: viewModel.layout)
        observePlayback()
        observeAlerts()
        observeLyrics()
        observeArtwork()
        observeTabs()
        observeLiveActivities()
        observePrivacy()
        observeEnergy()
    }

    private static func actions(
        for viewModel: IslandViewModel,
        services: IslandServices,
        dragHolder: String
    ) -> IslandActions {
        let nowPlaying = services.nowPlaying
        let hud = services.hud
        let alerts = services.alerts
        let lyrics = services.lyrics.model
        let shelf = services.shelf
        let store = shelf.store
        let clipboard = services.clipboard
        let calendar = services.calendar
        let screenshots = services.screenshots
        let timers = services.timers
        let systemTimers = services.systemTimers
        let transfers = services.transfers
        return IslandActions(
            player: PlayerActions(
                togglePlayPause: { [weak nowPlaying] in
                    Diagnostics.shared.record("notch: pulsante play/pausa premuto")
                    nowPlaying?.togglePlayPause()
                },
                nextTrack: { [weak nowPlaying] in nowPlaying?.nextTrack() },
                previousTrack: { [weak nowPlaying] in nowPlaying?.previousTrack() },
                seek: { [weak nowPlaying] position in nowPlaying?.seek(to: position) },
                toggleLyrics: { [weak lyrics] in
                    guard let lyrics else { return }
                    lyrics.setPanelEnabled(!lyrics.isPanelEnabled)
                },
                openSource: { [weak nowPlaying] in nowPlaying?.openSourceApp() },
                setInteracting: { [weak viewModel] interacting in
                    viewModel?.setInteracting(interacting, pointer: NSEvent.mouseLocation)
                },
                showOutputs: { [weak viewModel] in
                    // The menu lies outside the island: hold it open until the menu closes.
                    viewModel?.setInteracting(true, pointer: NSEvent.mouseLocation)
                    AudioOutputMenu.popUp(volume: services.volume)
                    viewModel?.setInteracting(false, pointer: NSEvent.mouseLocation)
                }
            ),
            hud: HUDActions(
                setLevel: { [weak hud] level in hud?.setLevel(level) },
                setInteracting: { [weak viewModel, weak alerts] interacting in
                    viewModel?.setInteracting(interacting, pointer: NSEvent.mouseLocation)
                    alerts?.setInteracting(interacting, by: dragHolder)
                }
            ),
            alerts: AlertActions(activate: { alert in services.activate(alert) }),
            shelf: ShelfActions(
                drop: { [weak shelf] providers in shelf?.drop(providers) },
                setTargeted: { [weak viewModel] targeted in viewModel?.setDropTargeted(targeted) },
                open: { [weak store] item in store?.open(item) },
                reveal: { [weak store] item in store?.reveal(item) },
                remove: { [weak store] item in store?.remove(item) },
                clear: { [weak store] in store?.clear() }
            ),
            clipboard: ClipboardActions(
                copy: { [weak clipboard] item in clipboard?.copy(item) },
                remove: { [weak clipboard] item in clipboard?.remove(item) },
                clear: { [weak clipboard] in clipboard?.clear() }
            ),
            calendar: CalendarActions(
                open: { [weak calendar] event in calendar?.open(event) },
                openSettings: { [weak calendar] in calendar?.openPrivacySettings() }
            ),
            screenshot: ScreenshotActions(
                open: { url in services.activate(.screenshot(ScreenshotAlert(url: url))) },
                copy: { [weak screenshots] url in screenshots?.copy(url) },
                keep: { [weak screenshots] url in screenshots?.keepOnShelf(url) },
                trash: { [weak screenshots] url in screenshots?.moveToTrash(url) }
            ),
            timer: TimerActions(
                start: { [weak timers, weak systemTimers] minutes in
                    guard let timers, let systemTimers else { return }
                    TimerCommands.start(minutes: minutes, timers: timers, systemTimers: systemTimers)
                },
                startPomodoro: { [weak timers] in timers?.startPomodoro() },
                togglePause: { [weak timers, weak systemTimers] in
                    guard let timers, let systemTimers else { return }
                    TimerCommands.togglePause(timers: timers, systemTimers: systemTimers)
                },
                addMinute: { [weak timers] in timers?.addMinute() },
                stop: { [weak timers, weak systemTimers] in
                    guard let timers, let systemTimers else { return }
                    TimerCommands.stop(timers: timers, systemTimers: systemTimers)
                },
                toggleStopwatch: { [weak timers] in timers?.toggleStopwatch() },
                resetStopwatch: { [weak timers] in timers?.resetStopwatch() }
            ),
            transfer: TransferActions(
                reveal: { [weak transfers] url in transfers?.reveal(url) },
                keep: { [weak transfers] url in transfers?.keepOnShelf(url) }
            ),
            selectTab: { [weak viewModel] tab in
                Haptics.perform(.step)
                viewModel?.selectTab(tab)
            }
        )
    }

    // MARK: Gestures

    /// Swipes over the open player: horizontal skips a track, vertical changes the volume;
    /// over the lyrics, scrolling browses them; over an alert, a swipe up dismisses it.
    private func scrolled(_ event: NSEvent) -> Bool {
        if viewModel.acceptsLyricsScroll, let window = event.window {
            // Canvas coordinates: origin at the top-left of the panel.
            let point = CGPoint(x: event.locationInWindow.x, y: window.frame.height - event.locationInWindow.y)
            if viewModel.layout.lyricsFrame.contains(point) {
                scrollLyrics(event)
                return true
            }
        }
        let dismisses = viewModel.acceptsDismissGesture
        guard Preferences.gesturesEnabled, viewModel.acceptsVolumeGestures || dismisses else { return false }
        let sample = ScrollSample(
            deltaX: Double(event.scrollingDeltaX),
            deltaY: Double(event.scrollingDeltaY),
            phase: Self.phase(of: event),
            isMomentum: event.momentumPhase != [],
            isPrecise: event.hasPreciseScrollingDeltas,
            isInverted: event.isDirectionInvertedFromDevice
        )
        switch scrollGesture.handle(sample, allowsTrackSkip: viewModel.acceptsTrackGestures, swipeUpDismisses: dismisses) {
        case .nextTrack:
            services.nowPlaying.nextTrack()
            Haptics.perform(.action)
        case .previousTrack:
            services.nowPlaying.previousTrack()
            Haptics.perform(.action)
        case .dismiss:
            viewModel.alertSwipedAway()
            services.alerts.dismissCurrent()
            Haptics.perform(.action)
        case .volume(let delta):
            if services.hud.nudgeVolume(by: delta) {
                Haptics.perform(.limit)
            }
        case nil:
            break
        }
        return true
    }

    /// Scrolling over the lyrics moves them like a list, momentum included; a wheel notch is
    /// one line.
    private func scrollLyrics(_ event: NSEvent) {
        let lyrics = services.lyrics.model
        let delta = Double(event.scrollingDeltaY)
        let lines = event.hasPreciseScrollingDeltas ? delta / Double(LyricsPanel.lineHeight) : delta
        let current = services.nowPlaying.model.timeline.flatMap {
            LyricsTimeline.displayedIndex(at: Date(), in: lyrics.lines, timeline: $0, lead: lyrics.lead)
        }
        viewModel.scrollLyrics(by: -lines, current: current ?? 0, count: lyrics.lines.count)
    }

    private static func phase(of event: NSEvent) -> ScrollSample.Phase {
        let phase = event.phase
        if phase.contains(.began) || phase.contains(.mayBegin) { return .began }
        if phase.contains(.ended) || phase.contains(.cancelled) { return .ended }
        if phase.contains(.changed) || phase.contains(.stationary) { return .changed }
        return .none
    }

    /// Makes the island a file drop target while a file drag is in progress.
    func fileDragChanged(_ dragging: Bool) {
        viewModel.fileDragChanged(dragging)
    }

    func update(screen: NSScreen) {
        let geometry = NotchGeometry(screen: screen)
        viewModel.updateGeometry(geometry)
        panelController.show(geometry: geometry, layout: viewModel.layout)
    }

    func pointerMoved(to location: CGPoint) {
        viewModel.pointerMoved(to: location)
    }

    func close() {
        services.alerts.setReading(false, by: holderID)
        panelController.hide()
    }

    // MARK: Observation

    // Each observer re-arms itself on every change: Observation reports the first change
    // after each registration, which keeps this event driven without any polling.

    private func observePlayback() {
        let player = services.nowPlaying.model
        let (isPlaying, hasMedia) = withObservationTracking {
            (player.isPlaying, player.hasMedia)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observePlayback()
            }
        }
        viewModel.playbackChanged(isPlaying: isPlaying, hasMedia: hasMedia)
    }

    private func observeAlerts() {
        let alerts = services.alerts
        let current = withObservationTracking {
            alerts.current
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeAlerts()
            }
        }
        viewModel.alertChanged(current)
    }

    private func observeArtwork() {
        let player = services.nowPlaying.model
        let size = withObservationTracking {
            player.artworkImage?.size
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeArtwork()
            }
        }
        viewModel.artworkChanged(size: size)
    }

    private func observeLyrics() {
        let lyrics = services.lyrics.model
        let showsPanel = withObservationTracking {
            lyrics.showsPanel
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeLyrics()
            }
        }
        viewModel.lyricsChanged(visible: showsPanel)
    }

    /// The optional tabs follow their features' switches.
    private func observeTabs() {
        let shelf = services.shelf
        let clipboard = services.clipboard
        let calendar = services.calendar
        let timers = services.timers
        let tabs = withObservationTracking {
            var tabs: [ExpandedTab] = []
            if shelf.isEnabled { tabs.append(.shelf) }
            if clipboard.isEnabled { tabs.append(.clipboard) }
            if calendar.isEnabled { tabs.append(.calendar) }
            if timers.isEnabled { tabs.append(.timer) }
            return tabs
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeTabs()
            }
        }
        viewModel.tabsChanged(tabs)
    }

    /// A timer, the stopwatch, a Clock timer or a download turns the compact island into a
    /// live activity.
    private func observeLiveActivities() {
        let timers = services.timers
        let systemTimers = services.systemTimers
        let transfers = services.transfers
        let active = withObservationTracking {
            LiveActivity.current(timers: timers, systemTimers: systemTimers, transfers: transfers) != nil
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeLiveActivities()
            }
        }
        viewModel.liveActivityChanged(active: active)
    }

    /// A microphone or camera in use keeps the island up with its dot.
    private func observePrivacy() {
        let privacy = services.privacy
        let inUse = withObservationTracking {
            privacy.active != nil
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observePrivacy()
            }
        }
        viewModel.privacyChanged(inUse: inUse)
    }

    private func observeEnergy() {
        let energy = services.energy
        let reduced = withObservationTracking {
            energy.reducesEffects
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeEnergy()
            }
        }
        viewModel.energyChanged(reduced: reduced)
    }
}
