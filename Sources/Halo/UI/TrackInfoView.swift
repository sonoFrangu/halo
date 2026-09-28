import SwiftUI

struct TrackInfoView: View {
    let title: String
    let artist: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.2)
                .foregroundStyle(.white)
            Text(artist ?? "")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
        }
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: title)
        .accessibilityElement(children: .combine)
    }
}
