import Foundation

/// Current conditions at a place.
struct WeatherReport: Sendable, Equatable {
    var temperature: Double
    var code: Int
    var isDay: Bool
    var usesFahrenheit: Bool

    var symbol: String {
        WeatherCode.symbol(for: code, isDay: isDay)
    }

    var summary: String {
        WeatherCode.description(for: code)
    }

    /// "22°", rounded like the system does.
    var temperatureText: String {
        "\(Int(temperature.rounded()))°"
    }
}

/// A coordinate, from Core Location or approximated from the IP address.
struct WeatherPlace: Sendable, Equatable {
    var latitude: Double
    var longitude: Double
}

/// Current weather from Open-Meteo (free, no API key).
enum WeatherService {
    private struct Response: Decodable {
        struct Current: Decodable {
            let temperature2m: Double
            let weatherCode: Int
            let isDay: Int

            enum CodingKeys: String, CodingKey {
                case temperature2m = "temperature_2m"
                case weatherCode = "weather_code"
                case isDay = "is_day"
            }
        }

        let current: Current
    }

    static func report(at place: WeatherPlace, fahrenheit: Bool) async throws -> WeatherReport {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.open-meteo.com"
        components.path = "/v1/forecast"
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.3f", place.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", place.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "temperature_unit", value: fahrenheit ? "fahrenheit" : "celsius"),
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 10))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let current = try JSONDecoder().decode(Response.self, from: data).current
        return WeatherReport(
            temperature: current.temperature2m,
            code: current.weatherCode,
            isDay: current.isDay != 0,
            usesFahrenheit: fahrenheit
        )
    }

    /// Rough position from the IP address (ipwho.is, free, no key), used only when
    /// location access is denied.
    static func approximatePlace() async throws -> WeatherPlace {
        struct Lookup: Decodable {
            let success: Bool
            let latitude: Double?
            let longitude: Double?
        }
        guard let url = URL(string: "https://ipwho.is/?fields=success,latitude,longitude") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 10))
        let lookup = try JSONDecoder().decode(Lookup.self, from: data)
        guard lookup.success, let latitude = lookup.latitude, let longitude = lookup.longitude else {
            throw URLError(.cannotFindHost)
        }
        return WeatherPlace(latitude: latitude, longitude: longitude)
    }
}
