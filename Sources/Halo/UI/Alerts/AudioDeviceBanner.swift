import SwiftUI

/// Banner shown when headphones connect: device, name, and a ring for each battery, drawn
/// with the model's own earbud and case symbols like the iPhone's battery card. Batteries
/// fill in when `system_profiler` reports them. Picture, name and rings come in one after
/// another.
struct AudioDeviceBanner: View {
    let alert: AudioDeviceAlert
    let isVisible: Bool

    var body: some View {
        let model = model
        HStack(spacing: 14) {
            DeviceGlyph(symbol: model.pair, productID: alert.productID, isVisible: isVisible)
                .frame(width: 40)
                .reveal(isVisible, order: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.name)
                    .font(Typography.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("Connesse")
                    .font(Typography.subheadline.weight(.medium))
                    .foregroundStyle(Ink.secondary)
            }
            .reveal(isVisible, order: 1)

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                ForEach(Array(rings(for: model).enumerated()), id: \.element.caption) { index, ring in
                    BatteryRing(value: ring.value, symbol: ring.symbol, caption: ring.caption)
                        .reveal(isVisible, order: 2 + index)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private struct Ring {
        let value: Double?
        let symbol: String
        let caption: String
    }

    private func rings(for model: Model) -> [Ring] {
        let batteries = alert.batteries
        func value(_ percent: Int?) -> Double? { percent.map { Double($0) / 100 } }
        if let main = batteries.main {
            return [Ring(value: value(main), symbol: model.pair, caption: "Batteria")]
        }
        if let earbuds = model.earbuds {
            return [
                Ring(value: value(batteries.left), symbol: earbuds.left, caption: "Sinistra"),
                Ring(value: value(batteries.right), symbol: earbuds.right, caption: "Destra"),
                Ring(value: value(batteries.case), symbol: earbuds.case, caption: "Custodia"),
            ]
        }
        return batteries.isEmpty ? [] : [
            Ring(value: value(batteries.left ?? batteries.right), symbol: model.pair, caption: "Batteria"),
        ]
    }

    /// SF Symbols for the device and, for AirPods, each earbud and the case.
    private struct Model {
        struct Earbuds {
            let left: String
            let right: String
            let `case`: String
        }

        let pair: String
        var earbuds: Earbuds?

        static let airPods = Model(pair: "airpods", earbuds: .init(left: "airpod.left", right: "airpod.right", case: "airpods.chargingcase"))
        static let airPods3 = Model(pair: "airpods.gen3", earbuds: .init(left: "airpod.gen3.left", right: "airpod.gen3.right", case: "airpods.gen3.chargingcase.wireless"))
        // SF Symbols has no gen4 earbuds; gen3 ones share their shape.
        static let airPods4 = Model(pair: "airpods.gen4", earbuds: .init(left: "airpod.gen3.left", right: "airpod.gen3.right", case: "airpods.gen4.chargingcase.wireless"))
        static let airPodsPro = Model(pair: "airpodspro", earbuds: .init(left: "airpodpro.left", right: "airpodpro.right", case: "airpodspro.chargingcase.wireless"))
        static let airPodsMax = Model(pair: "airpodsmax")
    }

    /// Follows `SystemVolume.route`, which already tells AirPods models apart by product.
    private var model: Model {
        switch alert.route {
        case .airPods: .airPods
        case .airPods3: .airPods3
        case .airPods4: .airPods4
        case .airPodsPro: .airPodsPro
        case .airPodsMax: .airPodsMax
        case .headphones: Model(pair: "headphones")
        case .speakers: Model(pair: "hifispeaker.fill")
        }
    }
}

/// The device (its product picture, or an SF Symbol for models macOS has none of) coming
/// into view once the banner has faded in: it grows gently into place without bounce and a
/// soft highlight glides across it. Plays once each time the banner shows; still with
/// Reduce Motion or reduced effects.
private struct DeviceGlyph: View {
    let symbol: String
    let productID: String?
    let isVisible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.reducesEffects) private var reducesEffects

    private struct Pose {
        var scale: Double = 1
        /// Highlight position, -1 (left of the glyph) to 1 (right of it).
        var sheen: Double = -1
    }

    /// Lets `Motion.reveal` fade the banner in first, or the entrance would be over by the
    /// time the glyph can be seen.
    private static let revealDelay = 0.3

    var body: some View {
        glyph
            // `repeating` rather than a trigger: it also plays when the banner is inserted
            // already visible, and trigger state would need `@State`, which Command Line
            // Tools builds cannot expand on the macOS 27 SDK.
            .keyframeAnimator(initialValue: Pose(), repeating: isVisible && !reduceMotion && !reducesEffects) { content, animated in
                // Not repeating, the animator reports the first keyframe; stay at rest
                // instead, so the glyph does not shrink while the banner fades out.
                let pose = isVisible ? animated : Pose()
                return content
                    .overlay {
                        LinearGradient(colors: [.clear, .white.opacity(0.8), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 18)
                            .rotationEffect(.degrees(20))
                            .offset(x: pose.sheen * 32)
                    }
                    .mask(outline)
                    .shadow(color: .black.opacity(0.45), radius: 4, y: 3)
                    .scaleEffect(pose.scale)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    MoveKeyframe(0.82)
                    LinearKeyframe(0.82, duration: Self.revealDelay)
                    SpringKeyframe(1, duration: 1.4, spring: .init(duration: 1.4, bounce: 0))
                }
                KeyframeTrack(\.sheen) {
                    MoveKeyframe(-1)
                    LinearKeyframe(-1, duration: Self.revealDelay + 0.6)
                    CubicKeyframe(1, duration: 1.4)
                    // ponytail: holds at rest so the entrance plays once per showing, but the
                    // animator keeps ticking until the banner hides (~4.5 s); move to a
                    // trigger if the view ever gets a place to keep state.
                    LinearKeyframe(1, duration: 60)
                }
            }
    }

    private var picture: NSImage? {
        productID.flatMap { BluetoothProduct.product(id: $0).image }
    }

    /// The product picture, or the symbol shaded white like the matte plastic so the
    /// highlight has something to brighten.
    @ViewBuilder private var glyph: some View {
        if let picture {
            Image(nsImage: picture)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                // Most pictures are 64 px: sharp at 32 pt on Retina, soft any larger.
                .frame(width: 32, height: 32)
        } else {
            Image(systemName: symbol)
                .font(Glyph.display)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.6)], startPoint: .top, endPoint: .bottom))
        }
    }

    /// Opaque silhouette that keeps the highlight on the glyph without dimming it twice.
    @ViewBuilder private var outline: some View {
        if picture != nil {
            glyph
        } else {
            Image(systemName: symbol)
                .font(Glyph.display)
        }
    }
}
