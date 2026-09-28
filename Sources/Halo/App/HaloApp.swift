import AppKit

/// Entry point. Halo is an agent app (`LSUIElement`): no Dock icon, no main menu, only the
/// menu bar item and the island panel.
@main
enum HaloApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}
