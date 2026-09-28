import CoreGraphics
import Foundation

/// Brightness of the built-in display through the private DisplayServices framework (the
/// same calls used by MonitorControl and Lunar). Loaded at runtime with `dlopen`, so a
/// macOS release without it only disables the brightness HUD instead of breaking launch.
@MainActor
final class DisplayBrightness {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias BrightnessChanged = @convention(c) (CGDirectDisplayID, Double) -> Void

    private let getBrightness: GetBrightness?
    private let setBrightness: SetBrightness?
    private let brightnessChanged: BrightnessChanged?

    init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            guard let handle, let pointer = dlsym(handle, name) else { return nil }
            return unsafeBitCast(pointer, to: type)
        }
        getBrightness = symbol("DisplayServicesGetBrightness", as: GetBrightness.self)
        setBrightness = symbol("DisplayServicesSetBrightness", as: SetBrightness.self)
        brightnessChanged = symbol("DisplayServicesBrightnessChanged", as: BrightnessChanged.self)
        if getBrightness == nil || setBrightness == nil {
            Log.hud.error("DisplayServices brightness API unavailable")
        }
    }

    /// The built-in panel, if it is active (not in clamshell mode).
    var builtInDisplay: CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return nil }
        return displays.first { CGDisplayIsBuiltin($0) != 0 }
    }

    /// Current brightness in 0...1, or `nil` when it cannot be read.
    func level() -> Double? {
        guard let getBrightness, let display = builtInDisplay else { return nil }
        var value: Float = 0
        guard getBrightness(display, &value) == 0 else { return nil }
        return Double(value)
    }

    /// Sets brightness in 0...1. Returns `false` if the system refused.
    @discardableResult
    func setLevel(_ level: Double) -> Bool {
        guard let setBrightness, let display = builtInDisplay else { return false }
        let clamped = min(max(level, 0), 1)
        guard setBrightness(display, Float(clamped)) == 0 else { return false }
        // Keeps Control Center's slider and the ambient-light logic in sync.
        brightnessChanged?(display, clamped)
        return true
    }
}
