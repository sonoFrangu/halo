import Foundation

/// Spotify plays video episodes through its embedded Chromium, which hands MediaRemote the
/// Chromium logo instead of the cover (re-encoded each time, so the bytes cannot be matched).
/// For an episode the cover comes from Spotify's scripting interface instead.
enum SpotifyEpisodeArtwork {
    /// The episode's cover URL, or "" for a song. Never launches Spotify.
    static let script = """
        if application id "com.spotify.client" is running then
            tell application id "com.spotify.client"
                set playing to current track
                if id of playing starts with "spotify:episode:" then return artwork url of playing
            end tell
        end if
        return ""
        """

    /// The episode's cover, or `nil` for a song (its MediaRemote artwork is right) and
    /// when Spotify cannot be asked or the download fails.
    static func fetch(using scripts: ScriptRunner) async -> Data? {
        guard
            let address = await scripts.value(script),
            let url = URL(string: address), url.scheme == "https",
            let (data, response) = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 10)),
            (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return data
    }
}
