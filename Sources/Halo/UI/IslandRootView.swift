import SwiftUI

/// The whole panel canvas: the expanded decoration (shadow and halo), the black morphing
/// body, and the content clipped to the body. Everything is derived from `island.state`,
/// which changes inside a spring, so shape and content frames animate as one.
struct IslandRootView: View {
    let island: IslandViewModel
    let models: IslandModels
    let actions: IslandActions

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let layout = island.layout
        let isExpanded = island.state == .expanded
        let shape = NotchShape(spec: layout.spec(for: island.state, context: island.context))
        let canvas = layout.canvasSize
        let palette = models.player.palette

        ZStack(alignment: .topLeading) {
            if isExpanded {
                IslandDecoration(
                    spec: layout.spec(for: .expanded, context: island.context),
                    palette: palette,
                    showsGlow: island.hasMedia && island.context.tab == .player && !reduceTransparency
                )
                .transition(
                    .asymmetric(
                        insertion: .opacity.animation(Motion.decorationIn(reduceMotion: reduceMotion)),
                        removal: .opacity.animation(Motion.decorationOut)
                    )
                )
            }

            shape.fill(Color.black)

            IslandContentView(island: island, models: models, actions: actions, layout: layout)
                .clipShape(shape)
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .ignoresSafeArea()
        .animation(Motion.palette, value: palette)
    }
}
