import AppKit

/// The product picture macOS shows for an Apple or Beats accessory (AirPods 4, AirPods Pro,
/// Beats Studio…), found by the product ID that `system_profiler` reports.
///
/// The pictures and the `AssetPaths*.plist` files mapping product IDs to them ship inside
/// CoreBluetoothUI, a private framework: when a macOS release moves them, lookups return
/// nil and the banner falls back to an SF Symbol.
enum BluetoothProduct {
    private static let framework = Bundle(path: "/System/Library/PrivateFrameworks/CoreBluetoothUI.framework")

    /// Product IDs (`"0x201B"`, hex digits upper-cased as in CoreBluetoothUI's tables) by
    /// device name, for every paired device, connected or not, out of
    /// `system_profiler SPBluetoothDataType -json`.
    static func ids(systemProfilerJSON data: Data) -> [String: String] {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let controllers = root["SPBluetoothDataType"] as? [[String: Any]]
        else {
            return [:]
        }
        var ids: [String: String] = [:]
        for controller in controllers {
            for section in ["device_connected", "device_not_connected"] {
                for entry in controller[section] as? [[String: Any]] ?? [] {
                    for (name, value) in entry {
                        if let id = (value as? [String: Any])?["device_productID"] as? String, id.hasPrefix("0x") {
                            ids[name] = "0x" + id.dropFirst(2).uppercased()
                        }
                    }
                }
            }
        }
        return ids
    }

    /// Product IDs by device name, read at launch (`refreshIDs`) so a device is known the
    /// moment it becomes the output.
    @MainActor private static var ids: [String: String] = [:]

    @MainActor static func refreshIDs() async {
        let fresh = await BluetoothBatteryReader.productIDs()
        ids.merge(fresh) { _, new in new }
    }

    /// The product ID of the paired device called `name` (CoreAudio and Bluetooth agree on
    /// names, up to case).
    @MainActor static func id(ofDevice name: String) -> String? {
        ids[name] ?? ids.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    /// What macOS knows about a product: its catalogue name ("AirPods Pro") and picture.
    struct Product {
        var name: String?
        var image: NSImage?
    }

    @MainActor private static var products: [String: Product] = [:]

    /// Looked up once per product, misses included: the banner asks on every frame of its
    /// animation.
    @MainActor static func product(id: String) -> Product {
        if let product = products[id] { return product }
        let entry = entry(productID: id)
        let product = Product(
            name: entry?["DisplayName"] as? String,
            image: imageURL(entry: entry).flatMap(NSImage.init(contentsOf:))
        )
        products[id] = product
        return product
    }

    /// The picture for `productID` (as `ids` reports it), in its default colour.
    static func imageURL(productID: String) -> URL? {
        imageURL(entry: entry(productID: productID))
    }

    private static func imageURL(entry: [String: Any]?) -> URL? {
        guard let framework, let name = entry?["ImageName"] as? String else { return nil }
        let bundle = (entry?["Bundle"] as? String).flatMap(Bundle.init(path:)) ?? framework
        return bundle.url(forResource: name, withExtension: nil)
    }

    private static func entry(productID key: String) -> [String: Any]? {
        guard let framework, let urls = framework.urls(forResourcesWithExtension: "plist", subdirectory: nil) else {
            return nil
        }
        let tables = urls
            .filter { $0.lastPathComponent.hasPrefix("AssetPaths") }
            .compactMap { NSDictionary(contentsOf: $0) as? [String: [String: Any]] }
        let entry = tables.lazy.compactMap { $0[key] }.first
        // Some entries only point at another product ID with the same picture.
        if let clone = entry?["Clone"] as? String {
            return tables.lazy.compactMap { $0[clone] }.first
        }
        return entry
    }
}
