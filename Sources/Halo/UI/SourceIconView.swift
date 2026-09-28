import AppKit
import SwiftUI

/// Icon of the app that is playing (e.g. Spotify, or Safari for a YouTube tab), shown as a
/// badge on the artwork's corner.
struct SourceIconView: View {
    let icon: NSImage?

    var body: some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                .accessibilityHidden(true)
        } else {
            Color.clear
        }
    }
}
