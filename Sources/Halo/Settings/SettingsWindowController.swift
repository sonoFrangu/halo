import AppKit
import SwiftUI

/// Opens (and reuses) the Settings window. Halo has no Dock icon, so the app is activated
/// first to bring the window in front.
@MainActor
final class SettingsWindowController {
    private let model: SettingsModel
    private var window: NSWindow?

    init(features: Features) {
        model = SettingsModel(features: features)
    }

    func show() {
        model.refresh()
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
        window.title = "Impostazioni di Halo"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
