import AppKit
import Testing
@testable import Halo

@MainActor
struct NotificationThumbnailTests {
    private func writePNG(width: Int, height: Int) throws -> URL {
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("halo-thumb-\(UUID()).png")
        try #require(rep.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    @Test func thumbnailIsSmallAndKeepsTheAspect() throws {
        let url = try writePNG(width: 1200, height: 800)
        let image = try #require(NotificationThumbnail.make(from: url))
        #expect(image.width == NotificationThumbnail.maxPixelSize)
        #expect((58...59).contains(image.height))
    }

    @Test func missingFileGivesNoThumbnail() {
        #expect(NotificationThumbnail.make(from: URL(fileURLWithPath: "/nonexistent/photo.jpg")) == nil)
    }

    @Test func loadCachesByNotification() async throws {
        let url = try writePNG(width: 300, height: 300)
        #expect(NotificationThumbnail.cached(424242) == nil)
        let image = await NotificationThumbnail.load(424242, from: url)
        #expect(image != nil)
        #expect(NotificationThumbnail.cached(424242) != nil)
    }
}
