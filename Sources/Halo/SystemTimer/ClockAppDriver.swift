import AppKit
import ApplicationServices

/// Drives the Timers tab of the Clock app through Accessibility: the only way another app
/// can start, pause, resume or cancel a Clock timer (`mobiletimerd` refuses outside
/// clients, and the Shortcuts "Start Timer" action fails on macOS 26).
///
/// Clock carries out a press only while it is the active app: pressing in the background
/// reports success and does nothing. So each command brings Clock forward for an instant,
/// with its window moved off screen, then gives focus back and hides it. Commands run one
/// at a time. Elements are found by identifier (or position, for the Timers tab), never by
/// their localized names.
@MainActor
final class ClockAppDriver {
    static let bundleIdentifier = "com.apple.clock"

    private var queue: Task<Bool, Never>?

    /// Starts a timer of `minutes` (typed into the hour, minute and second wheels).
    func start(minutes: Int) async -> Bool {
        await run("avvio \(minutes) min") { root in
            guard
                let picker = Self.element(in: root, identifier: "TimePicker"),
                let wheels = Self.children(of: picker), wheels.count == 3,
                let button = Self.element(in: root, identifier: "PauseResumeButton")
            else {
                return false
            }
            for (wheel, value) in zip(wheels, [0, minutes, 0]) {
                AXUIElementSetAttributeValue(wheel, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                AXUIElementPerformAction(wheel, kAXPressAction as CFString)
                await Self.settle(0.08)
                Self.type(String(value))
                await Self.settle(0.08)
            }
            return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
        }
    }

    /// Pauses the running timer, or resumes the paused one.
    func togglePause() async -> Bool {
        await run("pausa/riprendi") { root in
            Self.press(identifier: "PauseResumeButton", in: root)
        }
    }

    func cancel() async -> Bool {
        await run("annulla") { root in
            Self.press(identifier: "CancelButton", in: root)
        }
    }

    // MARK: Running a command

    private func run(_ label: String, _ body: @escaping @MainActor (AXUIElement) async -> Bool) async -> Bool {
        let previous = queue
        let task = Task { @MainActor [weak self] () -> Bool in
            _ = await previous?.value
            guard let self else { return false }
            let done = await self.perform(body)
            Diagnostics.shared.record("Orologio: \(label) \(done ? "fatto" : "non riuscito")")
            return done
        }
        queue = task
        return await task.value
    }

    private func perform(_ body: @MainActor (AXUIElement) async -> Bool) async -> Bool {
        guard AXIsProcessTrusted(), let clock = await launch() else { return false }
        let root = AXUIElementCreateApplication(clock.processIdentifier)
        guard let window = await Self.firstWindow(of: root) else { return false }
        let previous = NSWorkspace.shared.frontmostApplication

        var offscreen = CGPoint(x: -10_000, y: -10_000)
        if let position = AXValueCreate(.cgPoint, &offscreen) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
        }
        // `activate()` from an app in the background is refused since macOS 14; bringing
        // Clock forward through Accessibility is not. A hidden Clock must be shown and its
        // window raised first, or it does not become frontmost.
        AXUIElementSetAttributeValue(root, kAXHiddenAttribute as CFString, kCFBooleanFalse)
        await Self.settle(0.2)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(root, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        var done = false
        if await Self.wait(timeout: 1.5, until: { Self.attribute(root, kAXFrontmostAttribute) as? Bool == true }) {
            Self.selectTimersTab(in: root)
            await Self.settle(0.15)
            done = await body(root)
            await Self.settle(0.15)
        }
        if let previous, previous.processIdentifier != clock.processIdentifier {
            previous.activate()
        }
        clock.hide()
        return done
    }

    /// The running Clock app, or Clock launched hidden and in the background.
    private func launch() async -> NSRunningApplication? {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleIdentifier).first {
            return running
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleIdentifier) else { return nil }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.hides = true
        return try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    // MARK: Accessibility helpers

    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return value
    }

    private static func children(of element: AXUIElement) -> [AXUIElement]? {
        attribute(element, kAXChildrenAttribute) as? [AXUIElement]
    }

    private static func element(in root: AXUIElement, identifier: String) -> AXUIElement? {
        if attribute(root, kAXIdentifierAttribute) as? String == identifier { return root }
        for child in children(of: root) ?? [] {
            if let found = element(in: child, identifier: identifier) { return found }
        }
        return nil
    }

    private static func elements(in root: AXUIElement, role: String) -> [AXUIElement] {
        let own = attribute(root, kAXRoleAttribute) as? String == role ? [root] : []
        return own + (children(of: root) ?? []).flatMap { elements(in: $0, role: role) }
    }

    private static func press(identifier: String, in root: AXUIElement) -> Bool {
        guard let button = element(in: root, identifier: identifier) else { return false }
        return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
    }

    /// The toolbar's last segment (World Clock, Alarms, Stopwatch, Timers).
    private static func selectTimersTab(in root: AXUIElement) {
        guard
            let toolbar = elements(in: root, role: kAXToolbarRole).first,
            let tab = elements(in: toolbar, role: kAXRadioButtonRole).last,
            attribute(tab, kAXValueAttribute) as? Int != 1
        else {
            return
        }
        AXUIElementPerformAction(tab, kAXPressAction as CFString)
    }

    private static func firstWindow(of root: AXUIElement) async -> AXUIElement? {
        for _ in 0..<60 {
            if let window = (attribute(root, kAXWindowsAttribute) as? [AXUIElement])?.first {
                return window
            }
            await settle(0.05)
        }
        return nil
    }

    /// Types text into the frontmost app (Clock, by then) whatever the keyboard layout.
    private static func type(_ text: String) {
        for character in text.utf16 {
            for isDown in [true, false] {
                guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: isDown) else { continue }
                var unit = character
                event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unit)
                event.post(tap: .cghidEventTap)
            }
        }
    }

    private static func settle(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    private static func wait(timeout: Double, until condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else { return false }
            await settle(0.02)
        }
        return true
    }
}
