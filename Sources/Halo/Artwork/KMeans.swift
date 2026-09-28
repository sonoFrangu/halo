/// A group of similar colors and the fraction of samples it covers.
struct ColorCluster: Sendable, Equatable {
    var center: RGBColor
    var weight: Double
}

/// Tiny deterministic k-means over a few hundred color samples.
///
/// Seeding is farthest-first from the median-luminance sample instead of random picks, so
/// the same artwork always yields the same palette (no flicker when the adapter re-sends
/// identical artwork) and small but distinct colors still get their own cluster.
enum KMeans {
    static func clusters(of samples: [RGBColor], count: Int, iterations: Int = 10) -> [ColorCluster] {
        guard !samples.isEmpty, count > 0 else { return [] }
        let k = min(count, samples.count)

        var centers = seeds(from: samples, count: k)
        let clusterCount = centers.count
        var assignments = [Int](repeating: -1, count: samples.count)

        for _ in 0..<max(1, iterations) {
            var changed = false
            for (index, sample) in samples.enumerated() {
                let nearest = nearestCenter(to: sample, in: centers)
                if assignments[index] != nearest {
                    assignments[index] = nearest
                    changed = true
                }
            }
            if !changed { break }

            var sums = [(red: Double, green: Double, blue: Double, count: Int)](
                repeating: (0, 0, 0, 0), count: clusterCount
            )
            for (index, sample) in samples.enumerated() {
                let cluster = assignments[index]
                sums[cluster].red += sample.red
                sums[cluster].green += sample.green
                sums[cluster].blue += sample.blue
                sums[cluster].count += 1
            }
            for cluster in 0..<clusterCount where sums[cluster].count > 0 {
                let n = Double(sums[cluster].count)
                centers[cluster] = RGBColor(
                    red: sums[cluster].red / n,
                    green: sums[cluster].green / n,
                    blue: sums[cluster].blue / n
                )
            }
        }

        var counts = [Int](repeating: 0, count: clusterCount)
        for cluster in assignments {
            counts[cluster] += 1
        }
        let total = Double(samples.count)
        return (0..<clusterCount)
            .filter { counts[$0] > 0 }
            .map { ColorCluster(center: centers[$0], weight: Double(counts[$0]) / total) }
            .sorted { $0.weight > $1.weight }
    }

    private static func seeds(from samples: [RGBColor], count: Int) -> [RGBColor] {
        let byLuminance = samples.sorted { $0.luminance < $1.luminance }
        var seeds = [byLuminance[byLuminance.count / 2]]
        var nearestSeedDistance = samples.map { $0.distance(to: seeds[0]) }
        while seeds.count < count {
            guard
                let farthest = nearestSeedDistance.indices.max(by: { nearestSeedDistance[$0] < nearestSeedDistance[$1] }),
                nearestSeedDistance[farthest] > 0
            else {
                break
            }
            let seed = samples[farthest]
            seeds.append(seed)
            for index in samples.indices {
                nearestSeedDistance[index] = min(nearestSeedDistance[index], samples[index].distance(to: seed))
            }
        }
        return seeds
    }

    private static func nearestCenter(to sample: RGBColor, in centers: [RGBColor]) -> Int {
        var best = 0
        var bestDistance = Double.infinity
        for (index, center) in centers.enumerated() {
            let distance = sample.distance(to: center)
            if distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return best
    }
}
