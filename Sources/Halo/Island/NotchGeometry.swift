import AppKit

/// Where the notch is on a screen, in global AppKit coordinates (origin bottom-left).
struct NotchGeometry: Sendable, Equatable {
    var screenFrame: CGRect
    var notchCenterX: CGFloat
    var notchSize: CGSize
    /// `false` on displays without a camera housing: the island then grows from a fake notch.
    var hasPhysicalNotch: Bool

    static let virtualNotchWidth: CGFloat = 184
    static let defaultMenuBarHeight: CGFloat = 24

    /// Pure resolution logic, separated from `NSScreen` so it can be tested.
    ///
    /// With a notch, `safeAreaInsets.top` is its height and the auxiliary top areas are the
    /// usable menu bar strips on either side, so the notch is whatever lies between them.
    static func resolve(
        screenFrame: CGRect,
        safeAreaTop: CGFloat,
        auxiliaryLeftWidth: CGFloat?,
        auxiliaryRightWidth: CGFloat?,
        menuBarHeight: CGFloat
    ) -> NotchGeometry {
        if safeAreaTop > 0, let left = auxiliaryLeftWidth, let right = auxiliaryRightWidth {
            let width = screenFrame.width - left - right
            if width > 0 {
                return NotchGeometry(
                    screenFrame: screenFrame,
                    notchCenterX: screenFrame.minX + left + width / 2,
                    notchSize: CGSize(width: width, height: safeAreaTop),
                    hasPhysicalNotch: true
                )
            }
        }
        return NotchGeometry(
            screenFrame: screenFrame,
            notchCenterX: screenFrame.midX,
            notchSize: CGSize(
                width: virtualNotchWidth,
                height: menuBarHeight > 0 ? menuBarHeight : defaultMenuBarHeight
            ),
            hasPhysicalNotch: false
        )
    }

    @MainActor
    init(screen: NSScreen) {
        self = Self.resolve(
            screenFrame: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            auxiliaryLeftWidth: screen.auxiliaryTopLeftArea?.width,
            auxiliaryRightWidth: screen.auxiliaryTopRightArea?.width,
            menuBarHeight: screen.frame.maxY - screen.visibleFrame.maxY
        )
    }

    private init(screenFrame: CGRect, notchCenterX: CGFloat, notchSize: CGSize, hasPhysicalNotch: Bool) {
        self.screenFrame = screenFrame
        self.notchCenterX = notchCenterX
        self.notchSize = notchSize
        self.hasPhysicalNotch = hasPhysicalNotch
    }

    /// Rect of an island body of the given size, hanging from the top edge of the screen.
    func islandRect(width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: notchCenterX - width / 2, y: screenFrame.maxY - height, width: width, height: height)
    }
}
