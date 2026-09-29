import AppKit

/// Shows windows above the lock screen through the private SkyLight window-server API.
///
/// The lock screen is a system space with a high absolute level; a space created by the app
/// with an even higher level, shown and holding the app's windows, is drawn over it. The
/// space is created hidden. `show()` and `hide()` work from any thread, so the unlock can
/// hide it at once even while the main thread is stalled (see `UnlockWatch`). Every symbol
/// is resolved at run time with `dlopen`, so a macOS release without them disables the lock
/// screen card instead of breaking launch.
///
/// `@unchecked Sendable`: only immutable values; the SkyLight calls are requests to the
/// window server that touch no app state.
final class LockScreenSpace: @unchecked Sendable {
    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias SpaceCreate = @convention(c) (Int32, Int, Int) -> UInt64
    private typealias SpaceSetAbsoluteLevel = @convention(c) (Int32, UInt64, Int32) -> Int32
    private typealias SetSpacesVisible = @convention(c) (Int32, CFArray) -> Int32
    private typealias SpaceAddWindowsAndRemoveFromSpaces = @convention(c) (Int32, UInt64, CFArray, Int32) -> Int32

    /// Above the lock screen's own level (300).
    static let absoluteLevel: Int32 = 400
    /// "Remove from every other space" option of the add call.
    private static let moveOption: Int32 = 7

    private let connection: Int32
    private let space: UInt64
    private let showSpaces: SetSpacesVisible
    private let hideSpaces: SetSpacesVisible
    private let addWindows: SpaceAddWindowsAndRemoveFromSpaces

    init?() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) else {
            Log.app.error("SkyLight unavailable: no lock screen card")
            return nil
        }
        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            guard let pointer = dlsym(handle, name) else { return nil }
            return unsafeBitCast(pointer, to: type)
        }
        guard
            let mainConnectionID = symbol("SLSMainConnectionID", as: MainConnectionID.self),
            let spaceCreate = symbol("SLSSpaceCreate", as: SpaceCreate.self),
            let setAbsoluteLevel = symbol("SLSSpaceSetAbsoluteLevel", as: SpaceSetAbsoluteLevel.self),
            let showSpaces = symbol("SLSShowSpaces", as: SetSpacesVisible.self),
            let hideSpaces = symbol("SLSHideSpaces", as: SetSpacesVisible.self),
            let addWindows = symbol("SLSSpaceAddWindowsAndRemoveFromSpaces", as: SpaceAddWindowsAndRemoveFromSpaces.self)
        else {
            Log.app.error("SkyLight space API missing: no lock screen card")
            return nil
        }

        let connection = mainConnectionID()
        let space = spaceCreate(connection, 1, 0)
        guard space != 0 else {
            Log.app.error("SkyLight refused to create a space: no lock screen card")
            return nil
        }
        _ = setAbsoluteLevel(connection, space, Self.absoluteLevel)

        self.connection = connection
        self.space = space
        self.showSpaces = showSpaces
        self.hideSpaces = hideSpaces
        self.addWindows = addWindows
    }

    func show() {
        _ = showSpaces(connection, [NSNumber(value: space)] as CFArray)
    }

    func hide() {
        _ = hideSpaces(connection, [NSNumber(value: space)] as CFArray)
    }

    /// Moves `window` into the space above the lock screen. The window needs a window
    /// number, i.e. it must have been ordered in once.
    @MainActor
    func add(_ window: NSWindow) {
        guard window.windowNumber > 0 else { return }
        _ = addWindows(connection, space, [NSNumber(value: window.windowNumber)] as CFArray, Self.moveOption)
    }
}
