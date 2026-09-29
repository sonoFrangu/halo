import AppKit
import ImageIO

/// Small previews of notification photos. ImageIO decodes straight at thumbnail size (never
/// the full photo) on a background task; the last few are kept by notification id so the
/// banner can read them synchronously once posted.
@MainActor
enum NotificationThumbnail {
    /// Longest side in pixels: a 44-point square on a 2x display.
    nonisolated static let maxPixelSize = 88
    private static let limit = 10
    private static var images: [Int64: NSImage] = [:]
    private static var order: [Int64] = []

    static func cached(_ id: Int64) -> NSImage? {
        images[id]
    }

    /// The thumbnail of notification `id`, made once; `nil` when the file cannot be read.
    static func load(_ id: Int64, from url: URL) async -> NSImage? {
        if let image = images[id] {
            return image
        }
        guard let cgImage = await Task.detached(priority: .utility, operation: { make(from: url) }).value else {
            Diagnostics.shared.record("notifica \(id): miniatura non leggibile")
            return nil
        }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width) / 2, height: CGFloat(cgImage.height) / 2))
        images[id] = image
        order.append(id)
        if order.count > limit {
            images[order.removeFirst()] = nil
        }
        return image
    }

    nonisolated static func make(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
