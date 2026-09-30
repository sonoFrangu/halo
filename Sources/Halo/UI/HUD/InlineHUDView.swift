import SwiftUI

/// Compact HUD for the expanded island's header: glyph and draggable level bar.
struct InlineHUDView: View {
    let hud: HUDModel
    let hudActions: HUDActions

    var body: some View {
        HStack(spacing: 8) {
            HUDGlyph(kind: hud.kind, level: hud.level, isMuted: hud.isMuted, route: hud.route)
                .frame(width: 20)
            HUDLevelBar(
                level: hud.level,
                isMuted: hud.isMuted,
                onChange: hudActions.setLevel,
                onInteractionChanged: hudActions.setInteracting
            )
        }
    }
}
