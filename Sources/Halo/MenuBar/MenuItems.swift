import AppKit

/// A menu item that runs a closure.
@MainActor
final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, keyEquivalent: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(ActionMenuItem.run), keyEquivalent: keyEquivalent)
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("not used")
    }

    @objc private func run() {
        handler()
    }
}
