import SwiftUI

/// Shown when the island is hovered but nothing is playing, or when the adapter failed.
struct EmptyStateView: View {
    let availability: AdapterAvailability

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(Glyph.wing)
                .foregroundStyle(Ink.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundStyle(Ink.primary)
                if let detail {
                    Text(detail)
                        .font(Typography.subheadline)
                        .foregroundStyle(Ink.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var symbol: String {
        if case .unavailable = availability { return "exclamationmark.triangle.fill" }
        return "music.note"
    }

    private var title: String {
        if case .unavailable = availability { return "Now Playing non disponibile" }
        return "Niente in riproduzione"
    }

    private var detail: String? {
        if case .unavailable(let reason) = availability { return reason }
        return nil
    }
}
