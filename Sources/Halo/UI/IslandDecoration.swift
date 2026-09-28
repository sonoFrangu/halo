import SwiftUI

/// Drop shadow and colored halo of the expanded island.
///
/// Both are blurred copies of the *final* expanded outline, not of the morphing body: a
/// blur over a path that changes every frame has to be re-rasterized every frame, which is
/// what made the opening stutter. The decoration is inserted after the spring has nearly
/// settled (see `Motion.decorationIn`) and removed immediately on close. The black body is
/// drawn on top, so only the soft edges show.
struct IslandDecoration: View {
    let spec: IslandShapeSpec
    let palette: ArtworkPalette
    let showsGlow: Bool

    var body: some View {
        let shape = NotchShape(spec: spec)

        ZStack(alignment: .topLeading) {
            shape
                .fill(Color.black.opacity(0.55))
                .blur(radius: 16)
                .offset(y: 8)

            if showsGlow {
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
            }
        }
        .allowsHitTesting(false)
    }
}
