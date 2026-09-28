import SwiftUI

/// Shown when the island is hovered but nothing is playing, or when the adapter failed.
struct EmptyStateView: View {
    let availability: AdapterAvailability

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
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
