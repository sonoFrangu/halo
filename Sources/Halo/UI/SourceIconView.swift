import AppKit
import SwiftUI

/// Icon of the app that is playing (e.g. Spotify, or Safari for a YouTube tab).
struct SourceIconView: View {
    let icon: NSImage?

    var body: some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .accessibilityHidden(true)
        } else {
            Color.clear
        }
    }
}
