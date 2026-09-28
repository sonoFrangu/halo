import SwiftUI

/// Inner glow of the player: a radial wash of the artwork colors centered on the cover.
/// Masked out of the notch row so the top of the island stays pure black and keeps
/// blending with the hardware notch.
struct ExpandedBackdrop: View {
    let palette: ArtworkPalette
    let layout: IslandLayout
    let isVisible: Bool

    var body: some View {
        let canvas = layout.canvasSize
        let artwork = layout.artworkFrame(for: .expanded)
        let notchEdge = layout.notchSize.height / canvas.height
        let fadeEnd = (layout.notchSize.height + 30) / canvas.height

        RadialGradient(
            colors: [
                palette.primary.color.opacity(0.32),
                palette.secondary.color.opacity(0.12),
                .clear,
            ],
            center: UnitPoint(x: artwork.midX / canvas.width, y: artwork.midY / canvas.height),
            startRadius: 0,
            endRadius: 280
        )
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: notchEdge),
                    .init(color: .black, location: fadeEnd),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(false)
    }
}
