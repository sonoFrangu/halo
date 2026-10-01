import CoreGraphics
import Foundation

/// Whether the screen is being shared, recorded or mirrored: the moments macOS hides
/// notifications ("Allow notifications when mirroring or sharing the display" is off by
/// default). Read when a notification arrives, so nothing runs in between.
enum ScreenSharing {
    private typealias WatcherPresent = @convention(c) () -> Bool

    /// SkyLight's own check for apps watching the screen, loaded at runtime: a macOS
    /// release without it falls back to mirroring alone.
    private static let isWatcherPresent: WatcherPresent? = {
        guard
            let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
            let symbol = dlsym(handle, "SLSIsScreenWatcherPresent")
        else { return nil }
        return unsafeBitCast(symbol, to: WatcherPresent.self)
    }()

    static var isActive: Bool {
        isWatcherPresent?() == true || isMirroring
    }

    /// A display shows another's content (a projector or AirPlay in mirror mode).
    private static var isMirroring: Bool {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 1 else { return false }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return false }
        return displays.contains { CGDisplayIsInMirrorSet($0) != 0 }
    }
}
