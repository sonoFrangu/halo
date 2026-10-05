import SwiftUI

/// Left wing of a Focus alert: the Focus's own symbol, in its color while on.
struct FocusAlertGlyph: View {
    let alert: FocusAlert

    var body: some View {
        Image(systemName: alert.mode.symbol)
            .font(Glyph.wing)
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
                .font(Typography.callout.weight(.semibold))
                .foregroundStyle(alert.isOn ? Ink.primary : Ink.secondary)
            Text(alert.isOn ? "Attiva" : "Disattivata")
                .font(Typography.caption)
                .foregroundStyle(alert.isOn ? alert.mode.tint.color : Ink.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The unlock alert's symbol, in the style the alert carries.
struct UnlockGlyph: View {
    let style: UnlockAnimationStyle
    let isVisible: Bool

    var body: some View {
        Group {
            switch style {
            case .padlock: PadlockUnlockGlyph(isVisible: isVisible)
            case .faceID: FaceIDUnlockGlyph(isVisible: isVisible)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mac sbloccato")
    }
}

/// The padlock that springs open: shown closed as the alert appears, it opens a beat later.
private struct PadlockUnlockGlyph: View {
    let isVisible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: isVisible ? "lock.open.fill" : "lock.fill")
            .font(Glyph.wing)
            .foregroundStyle(.white)
            .contentTransition(.symbolEffect(.replace))
            .animation(reduceMotion ? nil : Motion.appear.delay(0.3), value: isVisible)
    }
}

/// The Face ID success sequence, frame for frame like Glance's `unlockanimation.mp4`
/// (1.22 s): the corner brackets grow into a rounded square while the face fades, the square
/// rounds into a circle, rings spin around it with motion trails, settle flat, and a
/// checkmark grows out of a dot. Geometry is in the video's 432-pixel space.
struct FaceIDUnlockGlyph: View {
    let isVisible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            ZStack {
                canvas(.start).opacity(isVisible ? 0 : 1)
                canvas(.done).opacity(isVisible ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.2).delay(0.3), value: isVisible)
        } else {
            // Re-runs on every change of `isVisible`; while hiding, the finished frame is drawn
            // so the fade-out does not replay the face.
            KeyframeAnimator(initialValue: Frame.start, trigger: isVisible) { frame in
                canvas(isVisible ? frame : .done)
            } keyframes: { _ in
                KeyframeTrack(\.join) {
                    LinearKeyframe(0, duration: 0.02)
                    CubicKeyframe(1, duration: 0.12)
                }
                KeyframeTrack(\.face) {
                    LinearKeyframe(1, duration: 0.05)
                    CubicKeyframe(0, duration: 0.16)
                }
                KeyframeTrack(\.round) {
                    LinearKeyframe(0, duration: 0.08)
                    CubicKeyframe(1, duration: 0.18)
                }
                KeyframeTrack(\.spin) {
                    LinearKeyframe(0, duration: 0.22)
                    CubicKeyframe(1, duration: 0.5, startVelocity: 3, endVelocity: 0)
                }
                KeyframeTrack(\.tilt) {
                    LinearKeyframe(0, duration: 0.22)
                    CubicKeyframe(1, duration: 0.1)
                    LinearKeyframe(1, duration: 0.28)
                    CubicKeyframe(0, duration: 0.14)
                }
                KeyframeTrack(\.trails) {
                    LinearKeyframe(0, duration: 0.28)
                    LinearKeyframe(1, duration: 0.08)
                    LinearKeyframe(1, duration: 0.24)
                    LinearKeyframe(0, duration: 0.12)
                }
                KeyframeTrack(\.check) {
                    LinearKeyframe(0, duration: 0.77)
                    CubicKeyframe(1, duration: 0.18)
                }
            }
        }
    }

    struct Frame {
        /// 0: short corner brackets; 1: they meet in a rounded square.
        var join: Double
        /// Opacity of eyes, nose and mouth.
        var face: Double
        /// 0: rounded square; 1: circle.
        var round: Double
        /// Progress of the rings' rotation.
        var spin: Double
        /// 0: rings flat on the circle; 1: tilted in 3D.
        var tilt: Double
        /// Opacity of the blurred motion trails.
        var trails: Double
        /// How much of the checkmark is drawn; a dot at the start thanks to the round cap.
        var check: Double

        static let start = Frame(join: 0, face: 1, round: 0, spin: 0, tilt: 0, trails: 0, check: 0)
        static let done = Frame(join: 1, face: 0, round: 1, spin: 1, tilt: 0, trails: 0, check: 1)
    }

    static let tint = Color(red: 0.2, green: 0.6, blue: 0.99)
    private static let space: CGFloat = 432
    private static let center = CGPoint(x: 216, y: 216)
    private static let lineWidth: CGFloat = 23
    /// Center-line half sizes and corner radius of the Face ID frame, and the circle's radius.
    private static let frameHalf = CGSize(width: 158.5, height: 151.5)
    private static let frameRadius: CGFloat = 48
    /// Arm length beyond the corner arc at rest.
    private static let restingArm: CGFloat = 16
    private static let circleRadius: CGFloat = 160.5

    private func canvas(_ frame: Frame) -> some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / Self.space
            var base = context
            base.translateBy(x: (size.width - Self.space * scale) / 2, y: (size.height - Self.space * scale) / 2)
            base.scaleBy(x: scale, y: scale)
            let shading = GraphicsContext.Shading.color(Self.tint)
            let stroke = StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round, lineJoin: .round)

            if frame.face > 0 {
                base.stroke(Self.face, with: .color(Self.tint.opacity(frame.face)), style: stroke)
            }
            if frame.tilt == 0 {
                base.stroke(outline(frame), with: shading, style: stroke)
            } else {
                if frame.trails > 0 {
                    var blurred = context
                    blurred.addFilter(.blur(radius: 7 * scale))
                    blurred.translateBy(x: (size.width - Self.space * scale) / 2, y: (size.height - Self.space * scale) / 2)
                    blurred.scaleBy(x: scale, y: scale)
                    for lag in 1...6 {
                        let alpha = 0.3 * frame.trails * (1 - Double(lag) / 7)
                        for ring in 0..<2 {
                            blurred.stroke(
                                Self.ring(ring, spin: frame.spin - 0.035 * Double(lag), tilt: frame.tilt),
                                with: .color(Self.tint.opacity(alpha)),
                                style: stroke
                            )
                        }
                    }
                }
                base.stroke(Self.ring(0, spin: frame.spin, tilt: frame.tilt), with: shading, style: stroke)
                base.stroke(Self.ring(1, spin: frame.spin, tilt: frame.tilt), with: .color(Self.tint.opacity(frame.tilt)), style: stroke)
            }
            if frame.check > 0 {
                base.stroke(Self.checkmark.trimmedPath(from: 0, to: max(0.001, frame.check)), with: shading, style: stroke)
            }
        }
    }

    /// The corner brackets, joined into a rounded square, rounded into a circle.
    private func outline(_ frame: Frame) -> Path {
        let half = CGSize(
            width: Self.frameHalf.width + (Self.circleRadius - Self.frameHalf.width) * frame.round,
            height: Self.frameHalf.height + (Self.circleRadius - Self.frameHalf.height) * frame.round
        )
        let radius = Self.frameRadius + (Self.circleRadius - Self.frameRadius) * frame.round
        let rect = CGRect(x: Self.center.x - half.width, y: Self.center.y - half.height, width: 2 * half.width, height: 2 * half.height)
        if frame.join >= 1 {
            return Path(roundedRect: rect, cornerRadius: radius, style: .circular)
        }
        // Each bracket: the corner's quarter arc plus an arm along each edge, growing to the
        // middle of the edge.
        let armX = Self.restingArm + (half.width - radius - Self.restingArm) * frame.join
        let armY = Self.restingArm + (half.height - radius - Self.restingArm) * frame.join
        var path = Path()
        for (sx, sy) in [(-1.0, -1.0), (1, -1), (1, 1), (-1, 1)] {
            let corner = CGPoint(x: Self.center.x + sx * half.width, y: Self.center.y + sy * half.height)
            let arcCenter = CGPoint(x: corner.x - sx * radius, y: corner.y - sy * radius)
            path.move(to: CGPoint(x: corner.x, y: arcCenter.y - sy * armY))
            path.addLine(to: CGPoint(x: corner.x, y: arcCenter.y))
            path.addArc(tangent1End: corner, tangent2End: CGPoint(x: arcCenter.x, y: corner.y), radius: radius)
            path.addLine(to: CGPoint(x: arcCenter.x - sx * armX, y: corner.y))
        }
        return path
    }

    /// One of the two spinning rings: the circle turned in 3D and projected flat, an ellipse
    /// whose axes turn as it spins. `tilt` blends it with the flat circle, so settling never
    /// passes through an edge-on line.
    private static func ring(_ index: Int, spin: Double, tilt: Double) -> Path {
        let (angle, axis) = index == 0
            ? (1.25 + 4 * spin, 0.15 + 1.5 * spin)
            : (1.9 + 5 * spin, 1.7 + 0.8 * spin)
        let minor = circleRadius * (1 - tilt * (1 - abs(cos(angle))))
        let ellipse = Path(ellipseIn: CGRect(x: -circleRadius, y: -minor, width: 2 * circleRadius, height: 2 * minor))
        return ellipse.applying(
            CGAffineTransform(translationX: center.x, y: center.y).rotated(by: axis)
        )
    }

    /// Eyes, nose and smile of the Face ID glyph.
    private static let face: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 146, y: 143)); path.addLine(to: CGPoint(x: 146, y: 182))
        path.move(to: CGPoint(x: 293, y: 143)); path.addLine(to: CGPoint(x: 293, y: 182))
        path.move(to: CGPoint(x: 232, y: 142)); path.addLine(to: CGPoint(x: 201, y: 230)); path.addLine(to: CGPoint(x: 234, y: 230))
        path.move(to: CGPoint(x: 141, y: 272)); path.addQuadCurve(to: CGPoint(x: 298, y: 272), control: CGPoint(x: 219, y: 332))
        return path
    }()

    private static let checkmark: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 150, y: 222))
        path.addLine(to: CGPoint(x: 205, y: 274))
        path.addLine(to: CGPoint(x: 290, y: 190))
        return path
    }()
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
                        .font(Glyph.tile)
                        .foregroundStyle(.white, tint)
                        .offset(x: 4, y: 4)
                }
                .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }

            VStack(alignment: .leading, spacing: 1) {
                Text(alert.kind == .airDrop ? "Ricevuto con AirDrop" : "Download completato")
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                Text(alert.name)
                    .font(Typography.headline)
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
                .font(Glyph.button)
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
