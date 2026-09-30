import SwiftUI

/// Left wing of a Focus alert: the Focus's own symbol, in its color while on.
struct FocusAlertGlyph: View {
    let alert: FocusAlert

    var body: some View {
        Image(systemName: alert.mode.symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(alert.isOn ? alert.mode.tint.color : Ink.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }
}

/// Right wing of a Focus alert: its name over "Attiva" / "Disattivata".
struct FocusAlertValue: View {
    let alert: FocusAlert

    var body: some View {
        VStack(alignment: .leading, spacing: -1) {
            Text(alert.mode.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(alert.isOn ? Ink.primary : Ink.secondary)
            Text(alert.isOn ? "Attiva" : "Disattivata")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(alert.isOn ? alert.mode.tint.color : Ink.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The padlock that springs open when the Mac is unlocked: shown closed as the alert
/// appears, it opens a beat later.
struct UnlockGlyph: View {
    let isVisible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: isVisible ? "lock.open.fill" : "lock.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .contentTransition(.symbolEffect(.replace))
            .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.3).delay(0.3), value: isVisible)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Mac sbloccato")
    }
}

/// What the transfer banner can ask for.
@MainActor
struct TransferActions {
    var reveal: (URL) -> Void
    var keep: (URL) -> Void
}

/// A download or AirDrop just finished: the file (drag it anywhere), where it came from,
/// and show in Finder / keep on the shelf. Clicking the banner opens the file.
struct TransferBanner: View {
    let alert: TransferAlert
    let thumbnails: ShelfThumbnails
    let actions: TransferActions

    var body: some View {
        let url = alert.url
        let tint = TransferPalette.tint(for: alert.kind)

        HStack(spacing: 12) {
            Image(nsImage: thumbnails.image(for: ShelfItem(url: url)))
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 46, height: 46)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white, tint)
                        .offset(x: 4, y: 4)
                }
                .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }

            VStack(alignment: .leading, spacing: 1) {
                Text(alert.kind == .airDrop ? "Ricevuto con AirDrop" : "Download completato")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                Text(alert.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .truncationMode(.middle)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                BannerIconButton(symbol: "magnifyingglass", label: "Mostra nel Finder") { actions.reveal(url) }
                BannerIconButton(symbol: "tray.and.arrow.down", label: "Tieni sullo scaffale") { actions.keep(url) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A small round button on a banner.
struct BannerIconButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Ink.primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Fill.primary))
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(label)
        .help(label)
    }
}
