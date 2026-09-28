import SwiftUI

/// Banner shown when headphones connect: device, name, and rings for each battery and the
/// volume. Batteries fill in when `system_profiler` reports them.
struct AudioDeviceBanner: View {
    let alert: AudioDeviceAlert

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("Connesse")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                ForEach(rings, id: \.caption) { ring in
                    BatteryRing(value: ring.value, symbol: ring.symbol, caption: ring.caption)
                }
                if let volume = alert.volume {
                    BatteryRing(value: volume, symbol: "speaker.wave.2.fill", caption: "Volume", tint: .white)
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

    private var rings: [Ring] {
        let batteries = alert.batteries
        func value(_ percent: Int?) -> Double? { percent.map { Double($0) / 100 } }
        if let main = batteries.main {
            return [Ring(value: value(main), symbol: "battery.100percent", caption: "Batteria")]
        }
        switch alert.route {
        case .airPods, .airPodsPro:
            return [
                Ring(value: value(batteries.left), symbol: "l.circle", caption: "Sinistra"),
                Ring(value: value(batteries.right), symbol: "r.circle", caption: "Destra"),
                Ring(value: value(batteries.case), symbol: "circle.bottomhalf.filled", caption: "Custodia"),
            ]
        default:
            return batteries.isEmpty ? [] : [
                Ring(value: value(batteries.left ?? batteries.right), symbol: "battery.100percent", caption: "Batteria"),
            ]
        }
    }

    private var symbol: String {
        switch alert.route {
        case .airPods: "airpods"
        case .airPodsPro: "airpodspro"
        case .airPodsMax: "airpodsmax"
        case .headphones: "headphones"
        case .speakers: "hifispeaker.fill"
        }
    }
}
