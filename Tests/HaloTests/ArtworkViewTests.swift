import AppKit
import SwiftUI
import Testing
@testable import Halo

@MainActor
struct ArtworkViewTests {
    /// A 16:9 cover (a YouTube thumbnail) must fill the square it is given, not widen it.
    @Test func wideArtworkKeepsTheProposedSize() {
        let wide = NSImage(size: NSSize(width: 1280, height: 720))
        let view = ArtworkView(image: wide, palette: .neutral, cornerRadius: 6, isProminent: false)
        let size = NSHostingController(rootView: view).sizeThatFits(in: CGSize(width: 40, height: 40))
        #expect(size == CGSize(width: 40, height: 40))
    }
}
