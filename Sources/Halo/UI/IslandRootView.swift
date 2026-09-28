import SwiftUI

/// The whole panel canvas: optional halo glow, the black morphing body, and the content
/// clipped to the body. Everything is derived from `island.state`, which changes inside
/// a spring, so shape, content frames and effects animate as one.
struct IslandRootView: View {
    let island: IslandViewModel
    let player: NowPlayingModel
    let actions: PlayerActions

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let layout = island.layout
        let isExpanded = island.state == .expanded
        let shape = NotchShape(spec: layout.spec(for: island.state, hasMedia: island.hasMedia))
        let canvas = layout.canvasSize

        ZStack(alignment: .topLeading) {
            if isExpanded && island.hasMedia && !reduceTransparency {
                HaloGlow(shape: shape, palette: player.palette)
                    .transition(.opacity.animation(.easeOut(duration: 0.14)))
            }

            shape
                .fill(Color.black)
                .shadow(color: .black.opacity(isExpanded ? 0.5 : 0), radius: 16, x: 0, y: 8)

            IslandContentView(island: island, player: player, actions: actions, layout: layout)
                .clipShape(shape)
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .ignoresSafeArea()
        .animation(Motion.palette, value: player.palette)
    }
}
