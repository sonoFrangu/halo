import Foundation

/// Identifies a track for a lyrics lookup.
struct LyricsQuery: Sendable, Hashable {
    var title: String
    var artist: String
    var album: String?
    /// Seconds, when known: LRCLIB uses it to pick the right version of a song.
    var duration: Int?
}

/// What a lookup found.
enum LyricsResult: Sendable, Equatable {
    case synced([LyricLine])
    /// Only unsynced text exists; Halo shows lyrics only when they follow the music.
    case plainOnly
    case notFound
}

/// Synced lyrics from LRCLIB (lrclib.net): free, open, no API key. It asks clients to
/// identify themselves with a User-Agent.
enum LyricsService {
    private static let userAgent = "Halo/0.1 (personal macOS notch app; https://github.com/sonoFrangu/halo)"

    private struct Record: Decodable {
        let syncedLyrics: String?
        let plainLyrics: String?
        let instrumental: Bool?
    }

    static func lyrics(for query: LyricsQuery) async throws -> LyricsResult {
        if let exact = try await get(query) {
            return result(from: exact)
        }
        // No exact match (e.g. a different album or a slightly different duration):
        // take the best search hit that has synced lyrics.
        let hits = try await search(query)
        if let synced = hits.first(where: { !($0.syncedLyrics ?? "").isEmpty }) {
            return result(from: synced)
        }
        return hits.isEmpty ? .notFound : .plainOnly
    }

    private static func result(from record: Record) -> LyricsResult {
        if let synced = record.syncedLyrics, !synced.isEmpty {
            let lines = LRCParser.parse(synced)
            return lines.isEmpty ? .plainOnly : .synced(lines)
        }
        return record.plainLyrics == nil && record.instrumental != true ? .notFound : .plainOnly
    }

    private static func get(_ query: LyricsQuery) async throws -> Record? {
        var items = [
            URLQueryItem(name: "track_name", value: query.title),
            URLQueryItem(name: "artist_name", value: query.artist),
        ]
        if let album = query.album, !album.isEmpty {
            items.append(URLQueryItem(name: "album_name", value: album))
        }
        if let duration = query.duration {
            items.append(URLQueryItem(name: "duration", value: String(duration)))
        }
        let (data, response) = try await fetch(path: "/api/get", items: items)
        if response.statusCode == 404 {
            return nil
        }
        return try JSONDecoder().decode(Record.self, from: data)
    }

    private static func search(_ query: LyricsQuery) async throws -> [Record] {
        let items = [
            URLQueryItem(name: "track_name", value: query.title),
            URLQueryItem(name: "artist_name", value: query.artist),
        ]
        let (data, _) = try await fetch(path: "/api/search", items: items)
        return (try? JSONDecoder().decode([Record].self, from: data)) ?? []
    }

    private static func fetch(path: String, items: [URLQueryItem]) async throws -> (Data, HTTPURLResponse) {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "lrclib.net"
        components.path = path
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 || http.statusCode == 404 else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}
