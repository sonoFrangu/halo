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
                    thumbnails: services.shelf.thumbnails
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

        panelController.show(geometry: geometry, layout: viewModel.layout)
        observePlayback()
        observeAlerts()
        observeLyrics()
        observeShelf()
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
        return IslandActions(
            player: PlayerActions(
                togglePlayPause: { [weak nowPlaying] in nowPlaying?.togglePlayPause() },
                nextTrack: { [weak nowPlaying] in nowPlaying?.nextTrack() },
                previousTrack: { [weak nowPlaying] in nowPlaying?.previousTrack() },
                seek: { [weak nowPlaying] position in nowPlaying?.seek(to: position) },
                toggleLyrics: { [weak lyrics] in
                    guard let lyrics else { return }
                    lyrics.setPanelEnabled(!lyrics.isPanelEnabled)
                },
                setInteracting: { [weak viewModel] interacting in
                    viewModel?.setInteracting(interacting, pointer: NSEvent.mouseLocation)
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
            selectTab: { [weak viewModel] tab in viewModel?.selectTab(tab) }
        )
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

    private func observeShelf() {
        let shelf = services.shelf
        let enabled = withObservationTracking {
            shelf.isEnabled
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeShelf()
            }
        }
        viewModel.shelfChanged(available: enabled)
    }
}
