import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Extracts a glow palette from encoded artwork: Core Image downsamples the image with a
/// Lanczos filter (a proper low-pass, so each sample averages its area), then a light
/// k-means finds the dominant colors. Runs off the main actor; ~600 samples take well
/// under a millisecond to cluster.
enum PaletteExtractor {
    private static let sampleSide = 24
    private static let clusterCount = 5

    /// `CIContext` is documented as thread-safe and is expensive to create, so one is shared.
    nonisolated(unsafe) private static let context = CIContext(options: [.cacheIntermediates: false])

    static func palette(from data: Data) -> ArtworkPalette? {
        guard let samples = samples(from: data), !samples.isEmpty else { return nil }
        return PaletteSelector.palette(from: KMeans.clusters(of: samples, count: clusterCount))
    }

    static func samples(from data: Data) -> [RGBColor]? {
        guard let image = CIImage(data: data) else { return nil }
        let extent = image.extent
        guard extent.width >= 1, extent.height >= 1, !extent.isInfinite else { return nil }

        let side = sampleSide
        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = image
        filter.scale = Float(Double(side) / extent.height)
        filter.aspectRatio = Float(extent.height / extent.width)
        guard
            let scaled = filter.outputImage,
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        else {
            return nil
        }

        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let bounds = CGRect(x: scaled.extent.minX, y: scaled.extent.minY, width: CGFloat(side), height: CGFloat(side))
        context.render(scaled, toBitmap: &pixels, rowBytes: side * 4, bounds: bounds, format: .RGBA8, colorSpace: colorSpace)

        var samples: [RGBColor] = []
        samples.reserveCapacity(side * side)
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[offset + 3]) / 255
            guard alpha >= 0.5 else { continue }
            // RGBA8 output is premultiplied.
            samples.append(RGBColor(
                red: min(1, Double(pixels[offset]) / 255 / alpha),
                green: min(1, Double(pixels[offset + 1]) / 255 / alpha),
                blue: min(1, Double(pixels[offset + 2]) / 255 / alpha)
            ))
        }
        return samples
    }
}
