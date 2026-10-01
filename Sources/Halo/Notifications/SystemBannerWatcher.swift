import AppKit
import ApplicationServices

/// A notification banner macOS just put on screen, read through Accessibility.
struct SystemBanner: Sendable, Equatable {
    /// The sending app's name as the banner shows it ("WhatsApp").
    var appName: String
    var title: String?
    var subtitle: String?
    var body: String?

    /// The banner's description lists the app's name and then its texts:
    /// "WhatsApp, Mario, Ciao". The name is what comes before the texts.
    static func appName(description: String, texts: [String]) -> String? {
        let suffix = texts.isEmpty ? "" : ", " + texts.joined(separator: ", ")
        guard description.hasSuffix(suffix) else { return nil }
        let name = String(description.dropLast(suffix.count))
        return name.isEmpty ? nil : name
    }
}

/// Reports notification banners the moment macOS shows them.
///
/// Notification Center saves a notification to its database only when its banner leaves
/// the screen, about five seconds later, so the database alone always arrives late. Its
/// banners are Accessibility elements (`AXNotificationCenterBanner`) holding the app's
/// name and the texts, and an Accessibility observer on its process says when they
/// appear. Without the Accessibility permission nothing is reported. Reading another
/// process can block, so it happens on a private queue.
@MainActor
final class SystemBannerWatcher {
    static let bundleIdentifier = "com.apple.notificationcenterui"

    private let onBanner: (SystemBanner) -> Void
    private let reader = BannerReader()
    private var observer: AXObserver?
    private var observedPID: pid_t?
    private var launchObserver: NSObjectProtocol?

    init(onBanner: @escaping (SystemBanner) -> Void) {
        self.onBanner = onBanner
    }

    func start() {
        guard launchObserver == nil else { return }
        // Notification Center relaunches after a crash; Accessibility may be granted later.
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.attach()
            }
        }
        attach()
    }

    func stop() {
        if let launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(launchObserver)
        }
        launchObserver = nil
        detach()
    }

    private func attach() {
        guard
            AXIsProcessTrusted(),
            let pid = NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleIdentifier).first?.processIdentifier,
            pid != observedPID
        else { return }
        detach()
        var created: AXObserver?
        guard AXObserverCreate(pid, bannerObserverCallback, &created) == .success, let observer = created else { return }
        let app = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXWindowCreatedNotification, kAXLayoutChangedNotification] {
            AXObserverAddNotification(observer, app, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        self.observer = observer
        observedPID = pid
        Log.app.info("watching notification banners")
    }

    private func detach() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        observedPID = nil
    }

    fileprivate func changed() {
        guard let pid = observedPID else { return }
        reader.read(pid: pid) { [weak self] banners in
            for banner in banners {
                self?.onBanner(banner)
            }
        }
    }
}

/// Reads the banners on a private serial queue. `@unchecked Sendable`: `seen` is touched
/// only on `queue`.
private final class BannerReader: @unchecked Sendable {
    private let queue = DispatchQueue(label: "io.github.sonofrangu.halo.banners", qos: .userInitiated)
    /// Banners already reported, by element and texts: Notification Center may reuse a
    /// banner for the next notification of the same app.
    private var seen: [String] = []

    private static let seenLimit = 50
    /// Notification Center answers in milliseconds; a hung one must not stall the reads.
    private static let messagingTimeout: Float = 0.5

    func read(pid: pid_t, deliver: @escaping @MainActor ([SystemBanner]) -> Void) {
        queue.async {
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, Self.messagingTimeout)
            var found: [SystemBanner] = []
            for window in Self.elements(app, kAXWindowsAttribute) {
                self.collect(in: window, depth: 0, into: &found)
            }
            guard !found.isEmpty else { return }
            Task { @MainActor in deliver(found) }
        }
    }

    private func collect(in element: AXUIElement, depth: Int, into found: inout [SystemBanner]) {
        // Banners sit a few levels down (window, hosting view, group, scroll area).
        guard depth < 6 else { return }
        if Self.string(element, kAXSubroleAttribute) == "AXNotificationCenterBanner" {
            if let (key, banner) = Self.banner(element), !seen.contains(key) {
                seen.append(key)
                if seen.count > Self.seenLimit { seen.removeFirst() }
                found.append(banner)
            }
            return
        }
        for child in Self.elements(element, kAXChildrenAttribute) {
            collect(in: child, depth: depth + 1, into: &found)
        }
    }

    private static func banner(_ element: AXUIElement) -> (String, SystemBanner)? {
        var texts: [String: String] = [:]
        for child in elements(element, kAXChildrenAttribute) {
            guard let id = string(child, kAXIdentifierAttribute), let value = string(child, kAXValueAttribute) else { continue }
            texts[id] = value
        }
        let ordered = ["title", "subtitle", "body"].compactMap { texts[$0] }
        guard
            !ordered.isEmpty,
            let description = string(element, kAXDescriptionAttribute),
            let appName = SystemBanner.appName(description: description, texts: ordered)
        else { return nil }
        let key = ([string(element, kAXIdentifierAttribute) ?? "", appName] + ordered).joined(separator: "\u{1F}")
        return (key, SystemBanner(appName: appName, title: texts["title"], subtitle: texts["subtitle"], body: texts["body"]))
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func elements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }
}

/// What the C callback hands to the main actor. `@unchecked Sendable`: the observer's run
/// loop source is on the main run loop, so the callback runs on the main thread.
private struct BannerObserverContext: @unchecked Sendable {
    let watcher: UnsafeMutableRawPointer
}

/// C callback of the Accessibility observer (always on the main thread, see above).
private func bannerObserverCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let context = BannerObserverContext(watcher: refcon)
    MainActor.assumeIsolated {
        Unmanaged<SystemBannerWatcher>.fromOpaque(context.watcher).takeUnretainedValue().changed()
    }
}
