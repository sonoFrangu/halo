/// WMO weather interpretation codes, as returned by Open-Meteo, mapped to SF Symbols and
/// a short Italian description.
enum WeatherCode {
    static func symbol(for code: Int, isDay: Bool) -> String {
        switch code {
        case 0: isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51, 53, 55, 56, 57: "cloud.drizzle.fill"
        case 61, 63, 66, 80, 81: "cloud.rain.fill"
        case 65, 67, 82: "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: "cloud.snow.fill"
        case 95: "cloud.bolt.fill"
        case 96, 99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }

    static func description(for code: Int) -> String {
        switch code {
        case 0: "Sereno"
        case 1: "Prevalentemente sereno"
        case 2: "Parzialmente nuvoloso"
        case 3: "Coperto"
        case 45, 48: "Nebbia"
        case 51, 53, 55: "Pioviggine"
        case 56, 57: "Pioviggine gelata"
        case 61, 63, 80, 81: "Pioggia"
        case 65, 82: "Pioggia forte"
        case 66, 67: "Pioggia gelata"
        case 71, 73, 75, 77, 85, 86: "Neve"
        case 95: "Temporale"
        case 96, 99: "Temporale con grandine"
        default: "—"
        }
    }
}
