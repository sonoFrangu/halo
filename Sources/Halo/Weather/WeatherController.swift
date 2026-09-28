import Foundation
import Observation

/// Weather for the expanded island's header.
@MainActor
@Observable
final class WeatherModel {
    private(set) var report: WeatherReport?

    fileprivate func update(_ report: WeatherReport) {
        self.report = report
    }

    fileprivate func clear() {
        report = nil
    }
}

/// Keeps the weather fresh without a timer: it refreshes when the island opens and the
/// last report is older than `staleAfter` (and once at launch), so a closed island costs
/// nothing.
@MainActor
final class WeatherController {
    let model = WeatherModel()

    private let location = LocationProvider()
    private var lastUpdate: Date?
    private var refreshTask: Task<Void, Never>?
    private(set) var isEnabled = Preferences.weatherEnabled

    static let staleAfter: TimeInterval = 20 * 60
    static let locationTimeout: Duration = .seconds(8)

    func start() {
        guard isEnabled else { return }
        refreshIfStale()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Preferences.weatherEnabled = enabled
        if enabled {
            refreshIfStale()
        } else {
            refreshTask?.cancel()
            lastUpdate = nil
            model.clear()
        }
    }

    func refreshIfStale() {
        guard isEnabled, refreshTask == nil else { return }
        if let lastUpdate, Date().timeIntervalSince(lastUpdate) < Self.staleAfter {
            return
        }
        refreshTask = Task { [weak self] in
            await self?.refresh()
            self?.refreshTask = nil
        }
    }

    private func refresh() async {
        let place: WeatherPlace?
        if let exact = await location.currentPlace(timeout: Self.locationTimeout) {
            place = exact
        } else {
            place = try? await WeatherService.approximatePlace()
        }
        guard let place, !Task.isCancelled else { return }

        let fahrenheit = Locale.current.measurementSystem == .us
        do {
            let report = try await WeatherService.report(at: place, fahrenheit: fahrenheit)
            guard isEnabled else { return }
            model.update(report)
            lastUpdate = Date()
        } catch {
            Log.app.info("weather update failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
