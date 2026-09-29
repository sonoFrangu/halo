import Foundation
import notify

/// Calls `onUnlock` on a private queue the moment the session unlocks, from the Darwin
/// notification loginwindow posts (`com.apple.sessionagent.screenIsUnlocked`). It does not
/// go through the main thread, so it still fires while the main thread is stalled: after a
/// wake on 2026-09-29 a stalled main thread kept the lock screen card over the desktop for
/// 29 s.
final class UnlockWatch {
    private static let name = "com.apple.sessionagent.screenIsUnlocked"
    private let queue = DispatchQueue(label: "io.github.sonofrangu.halo.unlock", qos: .userInteractive)
    private var token: Int32 = NOTIFY_TOKEN_INVALID

    init(onUnlock: @escaping @Sendable () -> Void) {
        let status = notify_register_dispatch(Self.name, &token, queue) { _ in
            onUnlock()
        }
        if status != NOTIFY_STATUS_OK {
            Log.app.error("unlock watch unavailable: notify status \(status)")
        }
    }

    deinit {
        if token != NOTIFY_TOKEN_INVALID {
            notify_cancel(token)
        }
    }
}
