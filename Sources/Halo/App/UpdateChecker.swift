import Foundation
import Observation

/// Asks GitHub for the latest release at launch, then at most once a day when the menu
/// opens, so a new version shows up in the menu and in Settings › Aggiornamenti. No timer
/// runs in between. Automatic checks can be turned off; "Controlla ora" always asks.
@MainActor
@Observable
final class UpdateChecker {
    struct Release: Equatable {
        let version: String
        let page: URL
    }

    /// A release newer than the running build, once one is known.
    private(set) var available: Release?
    private(set) var isChecking = false
    /// The last check that got an answer from GitHub.
    private(set) var lastSuccess: Date?
    /// The last check failed (offline, GitHub unreachable or rate-limited).
    private(set) var failed = false

    var checksAutomatically = Preferences.checksForUpdates {
        didSet { Preferences.checksForUpdates = checksAutomatically }
    }

    let runningVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    private static let endpoint = URL(string: "https://api.github.com/repos/sonoFrangu/halo/releases/latest")!
    private static let interval: TimeInterval = 24 * 60 * 60
    @ObservationIgnored private var lastAttempt: Date?

    /// At launch and when the menu opens: asks if automatic checks are on and a day has passed.
    func checkIfDue(now: Date = Date()) {
        guard checksAutomatically, lastAttempt.map({ now.timeIntervalSince($0) >= Self.interval }) ?? true else { return }
        check(now: now)
    }

    /// Asks GitHub now, unless a check is already running.
    func check(now: Date = Date()) {
        guard !isChecking else { return }
        lastAttempt = now
        isChecking = true
        Task { [weak self] in
            let release = try? await Self.fetchLatest()
            guard let self else { return }
            isChecking = false
            failed = release == nil
            guard let release else { return }
            lastSuccess = Date()
            available = Self.isNewer(release.version, than: runningVersion) ? release : nil
        }
    }

    /// "0.4.10" is newer than "0.4.9"; a leading "v" (the tag) is ignored.
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        plain(candidate).compare(plain(current), options: .numeric) == .orderedDescending
    }

    /// "v0.4.5" → "0.4.5".
    nonisolated static func plain(_ version: String) -> String {
        version.hasPrefix("v") ? String(version.dropFirst()) : version
    }

    private static func fetchLatest() async throws -> Release {
        struct Response: Decodable {
            let tagName: String
            let htmlUrl: URL
        }
        var request = URLRequest(url: endpoint, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let latest = try decoder.decode(Response.self, from: data)
        // The page opens in the browser: only ever a GitHub page.
        guard latest.htmlUrl.scheme == "https", latest.htmlUrl.host == "github.com" else { throw URLError(.badURL) }
        return Release(version: plain(latest.tagName), page: latest.htmlUrl)
    }
}
