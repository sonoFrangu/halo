import CoreLocation

/// One-shot location for the weather, through Core Location.
///
/// Asks for "when in use" access the first time. The delegate is called on the main
/// thread (the manager is created there), so results hop into the main actor directly.
@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var pending: [CheckedContinuation<WeatherPlace?, Never>] = []
    private var timeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// The current coordinate, or `nil` if location is denied, unavailable, or does not
    /// arrive within `timeout` (e.g. an unanswered permission prompt).
    func currentPlace(timeout: Duration) async -> WeatherPlace? {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            return nil
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
        return await withCheckedContinuation { continuation in
            pending.append(continuation)
            if pending.count == 1 {
                manager.requestLocation()
                timeoutTask = Task { [weak self] in
                    try? await Task.sleep(for: timeout)
                    guard !Task.isCancelled else { return }
                    self?.finish(nil)
                }
            }
        }
    }

    private func finish(_ place: WeatherPlace?) {
        timeoutTask?.cancel()
        timeoutTask = nil
        let waiting = pending
        pending.removeAll()
        for continuation in waiting {
            continuation.resume(returning: place)
        }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let place = locations.last.map {
            WeatherPlace(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        }
        MainActor.assumeIsolated {
            finish(place)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        MainActor.assumeIsolated {
            finish(nil)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            switch status {
            case .denied, .restricted:
                finish(nil)
            case .notDetermined:
                break
            default:
                if !pending.isEmpty {
                    self.manager.requestLocation()
                }
            }
        }
    }
}
