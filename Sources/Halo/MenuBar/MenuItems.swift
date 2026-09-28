import AppKit

/// A menu item that runs a closure.
@MainActor
class ActionMenuItem: NSMenuItem {
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

/// A checkmarked on/off item bound to a getter and setter.
@MainActor
final class ToggleMenuItem: ActionMenuItem {
    private let isOn: () -> Bool

    init(title: String, isOn: @escaping () -> Bool, setOn: @escaping (Bool) -> Void) {
        self.isOn = isOn
        super.init(title: title) {
            setOn(!isOn())
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("not used")
    }

    func refresh() {
        state = isOn() ? .on : .off
    }
}
