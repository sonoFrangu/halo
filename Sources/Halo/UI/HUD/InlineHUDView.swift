import SwiftUI

/// Compact HUD for the expanded island's header: glyph and draggable level bar.
struct InlineHUDView: View {
    let hud: HUDModel
    let tint: Color
    let hudActions: HUDActions

    var body: some View {
        HStack(spacing: 8) {
            HUDGlyph(kind: hud.kind, level: hud.level, isMuted: hud.isMuted, route: hud.route)
                .frame(width: 20)
            HUDLevelBar(
                kind: hud.kind,
                level: hud.level,
                isMuted: hud.isMuted,
                tint: tint,
                onChange: hudActions.setLevel,
                onInteractionChanged: hudActions.setInteracting
            )
        }
    }
}
