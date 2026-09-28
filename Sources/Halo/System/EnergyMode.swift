import Foundation
import Observation
import SwiftUI

/// Follows macOS Low Power Mode: while it is on (and the preference allows), Halo trims its
/// own work: no equalizer animation, simpler transitions without blur, a slower progress
/// bar, no scrolling titles.
@MainActor
@Observable
final class EnergyMode {
    private(set) var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    private(set) var adapts = Preferences.lowPowerAdaptive

    /// Effects are reduced right now.
    var reducesEffects: Bool {
        adapts && isLowPowerMode
    }

    @ObservationIgnored private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }

    func setAdapts(_ adapts: Bool) {
        self.adapts = adapts
        Preferences.lowPowerAdaptive = adapts
    }
}

private struct ReducesEffectsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Low Power Mode is on: views skip decorative motion (see `EnergyMode`).
    var reducesEffects: Bool {
        get { self[ReducesEffectsKey.self] }
        set { self[ReducesEffectsKey.self] = newValue }
    }
}
