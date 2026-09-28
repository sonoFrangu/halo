import SwiftUI

/// A soft colored halo around the expanded island: a blurred copy of the body painted
/// behind it in the artwork's colors. The body itself stays pure black on top.
struct HaloGlow: View {
    let shape: NotchShape
    let palette: ArtworkPalette

    var body: some View {
        shape
            .fill(
                LinearGradient(
                    colors: [palette.primary.color, palette.secondary.color],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .blur(radius: 22)
            .opacity(0.4)
            .allowsHitTesting(false)
    }
}
