import CoreGraphics
import Foundation
import ImageIO

/// Artwork ready for display: a decoded bitmap and its palette.
///
/// `@unchecked Sendable`: `CGImage` is immutable and safe to share across threads.
struct DecodedArtwork: @unchecked Sendable {
    let image: CGImage
    let palette: ArtworkPalette
}

/// Decodes artwork off the main actor.
///
/// Players hand over images up to a few thousand pixels wide. `NSImage(data:)` would defer
/// decoding to the first draw on the main thread (a hitch right when the island opens) and
/// keep the full-size bitmap around. A 320 px thumbnail, decoded eagerly here, is sharp at
/// the largest size Halo draws (84 pt @2x, about 300 px for a wide cover) and costs a fraction of the memory.
enum ArtworkDecoder {
    static let maximumPixelSize = 320

    static func decode(_ data: Data) -> DecodedArtwork? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return DecodedArtwork(image: image, palette: PaletteExtractor.palette(from: image) ?? .neutral)
    }
}
