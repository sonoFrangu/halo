import Foundation

/// A Focus (Full Immersione) as the system configures it.
struct FocusMode: Sendable, Equatable {
    var identifier: String
    var name: String
    /// SF Symbol chosen for the Focus.
    var symbol: String
    var tint: RGBColor
}

/// Reads the Do Not Disturb store in `~/Library/DoNotDisturb/DB`.
///
/// `Assertions.json` lists the Focus turned on by hand (Control Center, menu bar, a
/// shortcut): `data[0].storeAssertionRecords[].assertionDetails.assertionDetailsModeIdentifier`.
/// `ModeConfigurations.json` describes every Focus:
/// `data[0].modeConfigurations[id].mode.{name, symbolImageName, tintColorName}`.
/// The format is private; anything unexpected reads as "no Focus".
enum FocusStore {
    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/DoNotDisturb/DB", isDirectory: true)
    }

    static var assertionsURL: URL { directory.appendingPathComponent("Assertions.json") }
    static var configurationsURL: URL { directory.appendingPathComponent("ModeConfigurations.json") }

    /// The identifier of the Focus turned on by hand, if any; the latest one wins.
    static func activeIdentifier(assertions data: Data) -> String? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entries = root["data"] as? [[String: Any]]
        else { return nil }
        var latest: (identifier: String, start: Double)?
        for entry in entries {
            for record in entry["storeAssertionRecords"] as? [[String: Any]] ?? [] {
                guard
                    let details = record["assertionDetails"] as? [String: Any],
                    let identifier = details["assertionDetailsModeIdentifier"] as? String,
                    !identifier.isEmpty
                else { continue }
                let start = (record["assertionStartDateTimestamp"] as? NSNumber)?.doubleValue ?? 0
                if start >= latest?.start ?? -.infinity {
                    latest = (identifier, start)
                }
            }
        }
        return latest?.identifier
    }

    /// Every configured Focus by identifier.
    static func modes(configurations data: Data) -> [String: FocusMode] {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entries = root["data"] as? [[String: Any]]
        else { return [:] }
        var modes: [String: FocusMode] = [:]
        for entry in entries {
            let configurations = entry["modeConfigurations"] as? [String: Any] ?? [:]
            for (identifier, value) in configurations {
                let mode = (value as? [String: Any])?["mode"] as? [String: Any] ?? [:]
                modes[identifier] = self.mode(
                    identifier: identifier,
                    name: mode["name"] as? String,
                    symbol: mode["symbolImageName"] as? String,
                    tintName: mode["tintColorName"] as? String
                )
            }
        }
        return modes
    }

    /// Fills in what the store leaves out: Apple's own Focuses get their Italian name,
    /// symbol and color when the configuration has none.
    static func mode(identifier: String, name: String? = nil, symbol: String? = nil, tintName: String? = nil) -> FocusMode {
        let builtIn = builtIns.first { identifier.hasPrefix($0.prefix) }
        let resolvedName: String
        if let builtIn, name == nil || name == builtIn.englishName || name?.isEmpty == true {
            resolvedName = builtIn.name
        } else if let name, !name.isEmpty {
            resolvedName = name
        } else {
            resolvedName = "Full Immersione"
        }
        return FocusMode(
            identifier: identifier,
            name: resolvedName,
            symbol: symbol.flatMap { $0.isEmpty ? nil : $0 } ?? builtIn?.symbol ?? "moon.fill",
            tint: tintName.flatMap(color(named:)) ?? builtIn?.tint ?? indigo
        )
    }

    private struct BuiltIn {
        let prefix: String
        let englishName: String
        let name: String
        let symbol: String
        let tint: RGBColor
    }

    private static let indigo = RGBColor(red: 0.37, green: 0.36, blue: 0.9)

    private static let builtIns = [
        BuiltIn(prefix: "com.apple.donotdisturb.mode.default", englishName: "Do Not Disturb", name: "Non disturbare", symbol: "moon.fill", tint: indigo),
        BuiltIn(prefix: "com.apple.sleep", englishName: "Sleep", name: "Riposo", symbol: "bed.double.fill", tint: RGBColor(red: 0.19, green: 0.82, blue: 0.83)),
        BuiltIn(prefix: "com.apple.donotdisturb.mode.driving", englishName: "Driving", name: "Guida", symbol: "car.fill", tint: RGBColor(red: 0.2, green: 0.47, blue: 1)),
        BuiltIn(prefix: "com.apple.focus.work", englishName: "Work", name: "Lavoro", symbol: "briefcase.fill", tint: RGBColor(red: 0.26, green: 0.71, blue: 0.98)),
        BuiltIn(prefix: "com.apple.focus.personal", englishName: "Personal", name: "Tempo personale", symbol: "person.fill", tint: RGBColor(red: 0.69, green: 0.32, blue: 0.87)),
        BuiltIn(prefix: "com.apple.focus.reading", englishName: "Reading", name: "Lettura", symbol: "book.fill", tint: RGBColor(red: 1, green: 0.62, blue: 0.04)),
        BuiltIn(prefix: "com.apple.focus.gaming", englishName: "Gaming", name: "Gioco", symbol: "gamecontroller.fill", tint: RGBColor(red: 0.2, green: 0.47, blue: 1)),
        BuiltIn(prefix: "com.apple.focus.fitness", englishName: "Fitness", name: "Fitness", symbol: "figure.run", tint: RGBColor(red: 0.2, green: 0.78, blue: 0.35)),
        BuiltIn(prefix: "com.apple.focus.mindfulness", englishName: "Mindfulness", name: "Consapevolezza", symbol: "leaf.fill", tint: RGBColor(red: 0.19, green: 0.82, blue: 0.83)),
    ]

    /// `systemBlueColor` and friends, as stored by the Focus settings.
    static func color(named name: String) -> RGBColor? {
        switch name {
        case "systemRedColor": RGBColor(red: 1, green: 0.23, blue: 0.19)
        case "systemOrangeColor": RGBColor(red: 1, green: 0.58, blue: 0)
        case "systemYellowColor": RGBColor(red: 1, green: 0.8, blue: 0)
        case "systemGreenColor": RGBColor(red: 0.2, green: 0.78, blue: 0.35)
        case "systemMintColor": RGBColor(red: 0, green: 0.78, blue: 0.75)
        case "systemTealColor": RGBColor(red: 0.19, green: 0.69, blue: 0.78)
        case "systemCyanColor": RGBColor(red: 0.2, green: 0.68, blue: 0.9)
        case "systemBlueColor": RGBColor(red: 0, green: 0.48, blue: 1)
        case "systemIndigoColor": indigo
        case "systemPurpleColor": RGBColor(red: 0.69, green: 0.32, blue: 0.87)
        case "systemPinkColor": RGBColor(red: 1, green: 0.18, blue: 0.33)
        case "systemBrownColor": RGBColor(red: 0.64, green: 0.52, blue: 0.37)
        case "systemGrayColor": RGBColor(red: 0.56, green: 0.56, blue: 0.58)
        default: nil
        }
    }
}
