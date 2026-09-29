import Testing
@testable import Halo

struct PaletteTests {
    private func isClose(_ a: Double, _ b: Double, tolerance: Double = 0.001) -> Bool {
        abs(a - b) <= tolerance
    }

    @Test func hsbRoundTrips() {
        let colors = [
            RGBColor(red: 1, green: 0, blue: 0),
            RGBColor(red: 0.2, green: 0.6, blue: 0.9),
            RGBColor(red: 0.95, green: 0.8, blue: 0.1),
            RGBColor(red: 0.5, green: 0.5, blue: 0.5),
        ]
        for color in colors {
            let hsb = color.hsb
            let back = RGBColor(hue: hsb.hue, saturation: hsb.saturation, brightness: hsb.brightness)
            #expect(isClose(back.red, color.red))
            #expect(isClose(back.green, color.green))
            #expect(isClose(back.blue, color.blue))
        }
    }

    @Test func kMeansSeparatesDistinctColors() {
        let red = RGBColor(red: 0.9, green: 0.1, blue: 0.1)
        let blue = RGBColor(red: 0.1, green: 0.2, blue: 0.9)
        let samples = Array(repeating: red, count: 30) + Array(repeating: blue, count: 10)
        let clusters = KMeans.clusters(of: samples, count: 2)
        #expect(clusters.count == 2)
        #expect(clusters[0].center.distance(to: red) < 0.01)
        #expect(isClose(clusters[0].weight, 0.75))
        #expect(clusters[1].center.distance(to: blue) < 0.01)
    }

    @Test func kMeansIsDeterministic() {
        var samples: [RGBColor] = []
        for index in 0..<200 {
            let red = Double(index % 7) / 7
            let green = Double(index % 11) / 11
            let blue = Double(index % 5) / 5
            samples.append(RGBColor(red: red, green: green, blue: blue))
        }
        #expect(KMeans.clusters(of: samples, count: 5) == KMeans.clusters(of: samples, count: 5))
    }

    @Test func kMeansHandlesDegenerateInput() {
        #expect(KMeans.clusters(of: [], count: 3).isEmpty)
        let one = KMeans.clusters(of: [RGBColor(red: 0.3, green: 0.3, blue: 0.3)], count: 4)
        #expect(one.count == 1)
        #expect(isClose(one[0].weight, 1))
    }

    @Test func vividColorBeatsLargeBlackBackground() {
        let clusters = [
            ColorCluster(center: RGBColor(red: 0.02, green: 0.02, blue: 0.03), weight: 0.7),
            ColorCluster(center: RGBColor(red: 0.9, green: 0.3, blue: 0.5), weight: 0.3),
        ]
        let palette = PaletteSelector.palette(from: clusters)
        let hsb = palette.primary.hsb
        #expect(abs(hsb.hue - RGBColor(red: 0.9, green: 0.3, blue: 0.5).hsb.hue) < 0.01)
    }

    @Test func glowColorsAreVisibleOnBlack() {
        let dark = PaletteSelector.glow(RGBColor(red: 0.1, green: 0.05, blue: 0.3))
        #expect(dark.hsb.brightness >= 0.72 - 0.001)
        let neon = PaletteSelector.glow(RGBColor(red: 0, green: 1, blue: 0))
        #expect(neon.hsb.saturation <= 0.85 + 0.001)
        let gray = PaletteSelector.glow(RGBColor(red: 0.4, green: 0.4, blue: 0.4))
        #expect(gray == ArtworkPalette.neutral.primary)
    }

    @Test func emptyClustersFallBackToNeutral() {
        #expect(PaletteSelector.palette(from: []) == .neutral)
    }

    @Test func equalizerLevelsStayInRange() {
        for bar in -1...5 {
            for step in 0..<200 {
                let level = EqualizerWave.level(bar: bar, time: 700_000_000 + Double(step) * 0.033)
                #expect(level >= EqualizerWave.pausedLevel && level <= 1)
            }
        }
    }

    /// The baked Core Animation track loops without a jump only if the wave repeats.
    @Test func equalizerWaveRepeatsEveryPeriod() {
        for bar in 0..<EqualizerWave.barCount {
            for step in 0..<50 {
                let time = Double(step) * 0.137
                let later = EqualizerWave.level(bar: bar, time: time + EqualizerWave.period)
                #expect(abs(EqualizerWave.level(bar: bar, time: time) - later) < 1e-9)
            }
            let frames = EqualizerWave.keyframes(bar: bar)
            #expect(frames.count == Int(EqualizerWave.period) * EqualizerWave.keyframeRate + 1)
            #expect(abs(frames[0] - frames[frames.count - 1]) < 1e-9)
        }
    }
}
