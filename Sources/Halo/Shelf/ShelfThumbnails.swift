import AppKit
import Observation
import QuickLookThumbnailing

/// Quick Look thumbnails of shelf files (real previews for images, PDFs, documents),
/// generated off the main thread and cached; the Finder icon stands in until then.
@MainActor
@Observable
final class ShelfThumbnails {
    private(set) var images: [String: NSImage] = [:]
    @ObservationIgnored private var requested: Set<String> = []

    static let pixelSize = CGSize(width: 96, height: 96)

    func image(for item: ShelfItem) -> NSImage {
        if let thumbnail = images[item.id] {
            return thumbnail
        }
        request(item)
        return NSWorkspace.shared.icon(forFile: item.url.path)
    }

    private func request(_ item: ShelfItem) {
        guard requested.insert(item.id).inserted else { return }
        let request = QLThumbnailGenerator.Request(
            fileAt: item.url,
            size: Self.pixelSize,
            scale: 2,
            representationTypes: .thumbnail
        )
        let id = item.id
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            guard let cgImage = representation?.cgImage else { return }
            let thumbnail = ThumbnailBox(image: cgImage)
            Task { @MainActor [weak self] in
                self?.images[id] = NSImage(cgImage: thumbnail.image, size: .zero)
            }
        }
    }
}

/// `@unchecked Sendable`: `CGImage` is immutable.
private struct ThumbnailBox: @unchecked Sendable {
    let image: CGImage
}
