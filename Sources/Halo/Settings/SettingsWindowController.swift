import AppKit
import SwiftUI

/// Opens (and reuses) the Settings window. Halo has no Dock icon, so the app is activated
/// first to bring the window in front. Coming back to Halo (e.g. from System Settings
/// after granting a permission) re-reads what may have changed.
@MainActor
final class SettingsWindowController {
    private let model: SettingsModel
    private var window: NSWindow?
    private var activationObserver: NSObjectProtocol?

    init(features: Features) {
        model = SettingsModel(features: features)
    }

    /// Permissions a feature that is on still needs.
    var missingPermissions: [SettingsPermission] {
        model.missingPermissions
    }

    func show(pane: SettingsPane? = nil) {
        if let pane {
            model.pane = pane
        }
        model.refresh()
        let window = self.window ?? makeWindow()
        self.window = window
        observeActivation()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsView(model: model))
        hosting.sceneBridgingOptions = [.title, .toolbars]
        let window = NSWindow(contentViewController: hosting)
        window.title = "Impostazioni di Halo"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 800, height: 640))
        window.center()
        return window
    }

    private func observeActivation() {
        guard activationObserver == nil else { return }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.window?.isVisible == true else { return }
                self.model.refresh()
            }
        }
    }
}
