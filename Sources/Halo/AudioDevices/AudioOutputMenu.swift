import AppKit

/// The output picker opened from the player: the output devices, the current one ticked.
/// Choosing one makes it the default output, as in System Settings › Sound.
@MainActor
enum AudioOutputMenu {
    /// Shows the menu at the pointer and returns once it closes.
    static func popUp(volume: SystemVolume) {
        let current = volume.defaultOutputDevice
        let menu = NSMenu()
        menu.addItem(.sectionHeader(title: "Uscita audio"))
        for output in volume.outputs() {
            let item = ActionMenuItem(title: output.name) {
                volume.setDefaultOutput(output.id)
            }
            item.state = output.id == current ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}
