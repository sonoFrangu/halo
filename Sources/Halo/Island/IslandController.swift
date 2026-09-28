import AppKit
import Observation

/// Composition root of the island: connects screen changes, pointer movement and playback
/// state to the view model, and the view model to the panel.
@MainActor
final class IslandController {
    private let viewModel: IslandViewModel
    private let player: NowPlayingModel
    private let hud: HUDModel
    private let panelController: IslandPanelController
    private var screenTracker: ScreenTracker?
    private var pointerMonitor: PointerMonitor?

    init(nowPlaying: NowPlayingController, hud hudController: HUDController) {
        let screen = ScreenTracker.preferredScreen()
        let geometry = screen.map { NotchGeometry(screen: $0) } ?? Self.fallbackGeometry
        let viewModel = IslandViewModel(geometry: geometry)
        let actions = PlayerActions(
            togglePlayPause: { [weak nowPlaying] in nowPlaying?.togglePlayPause() },
            nextTrack: { [weak nowPlaying] in nowPlaying?.nextTrack() },
            previousTrack: { [weak nowPlaying] in nowPlaying?.previousTrack() },
            seek: { [weak nowPlaying] position in nowPlaying?.seek(to: position) },
            setInteracting: { [weak viewModel] interacting in
                viewModel?.setInteracting(interacting, pointer: NSEvent.mouseLocation)
            }
        )
        let hudActions = HUDActions(
            setLevel: { [weak hudController] level in hudController?.setLevel(level) },
            setInteracting: { [weak viewModel, weak hudController] interacting in
                viewModel?.setInteracting(interacting, pointer: NSEvent.mouseLocation)
                hudController?.setInteracting(interacting)
            }
        )

        self.viewModel = viewModel
        self.player = nowPlaying.model
        self.hud = hudController.model
        self.panelController = IslandPanelController(
            rootView: IslandRootView(
                island: viewModel,
                player: nowPlaying.model,
                hud: hudController.model,
                actions: actions,
                hudActions: hudActions
            )
        )

        viewModel.onInteractivityChange = { [weak self] interactive in
            self?.panelController.setInteractive(interactive)
        }
        panelController.onPointerActivity = { [weak self] in
            self?.pointerMoved()
        }
        screenTracker = ScreenTracker { [weak self] in
            self?.screensChanged()
        }
        pointerMonitor = PointerMonitor { [weak self] in
            self?.pointerMoved()
        }

        if screen != nil {
            panelController.show(geometry: geometry, layout: viewModel.layout)
        }
        observePlayback()
        observeHUD()
    }

    private static let fallbackGeometry = NotchGeometry.resolve(
        screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        safeAreaTop: 0,
        auxiliaryLeftWidth: nil,
        auxiliaryRightWidth: nil,
        menuBarHeight: NotchGeometry.defaultMenuBarHeight
    )

    private func pointerMoved() {
        viewModel.pointerMoved(to: NSEvent.mouseLocation)
    }

    private func screensChanged() {
        guard let screen = ScreenTracker.preferredScreen() else {
            panelController.hide()
            return
        }
        let geometry = NotchGeometry(screen: screen)
        viewModel.updateGeometry(geometry)
        panelController.show(geometry: geometry, layout: viewModel.layout)
    }

    /// Re-arms itself on every change: Observation reports the first change after each
    /// registration, which keeps this event driven without any polling.
    private func observePlayback() {
        let (isPlaying, hasMedia) = withObservationTracking {
            (player.isPlaying, player.hasMedia)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observePlayback()
            }
        }
        viewModel.playbackChanged(isPlaying: isPlaying, hasMedia: hasMedia)
    }

    private func observeHUD() {
        let isVisible = withObservationTracking {
            hud.isVisible
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeHUD()
            }
        }
        viewModel.hudChanged(isVisible: isVisible)
    }
}
