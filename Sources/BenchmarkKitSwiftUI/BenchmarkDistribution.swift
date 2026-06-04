import BenchmarkKit
import Foundation

/// Percentile summary for a set of sample values.
///
/// `BenchmarkSampleSummary` only stores `mean / min / max / latest`; the dashboard
/// distribution chart needs `p50 / p95 / p99` and a histogram. Computed lazily from
/// the metric history points so that no changes are required in the core model.
struct BenchmarkDistribution: Hashable, Sendable {
    /// The samples included in the distribution, sorted ascending.
    var sortedValues: [Double]

    /// The number of samples.
    var count: Int { sortedValues.count }

    /// Whether the distribution has enough samples to draw percentile bands meaningfully.
    var hasEnoughSamplesForPercentiles: Bool { sortedValues.count >= 5 }

    /// The minimum sample value.
    var minimum: Double? { sortedValues.first }

    /// The maximum sample value.
    var maximum: Double? { sortedValues.last }

    /// The 50th percentile (median).
    var p50: Double? { percentile(0.50) }

    /// The 95th percentile.
    var p95: Double? { percentile(0.95) }

    /// The 99th percentile.
    var p99: Double? { percentile(0.99) }

    /// Returns the value at the supplied percentile in `[0, 1]` using linear
    /// interpolation between the two nearest ranks.
    func percentile(_ p: Double) -> Double? {
        guard !sortedValues.isEmpty else { return nil }
        let clamped = max(0, min(1, p))
        if sortedValues.count == 1 { return sortedValues[0] }
        let rank = clamped * Double(sortedValues.count - 1)
        let lowerIndex = Int(rank.rounded(.down))
        let upperIndex = Int(rank.rounded(.up))
        if lowerIndex == upperIndex { return sortedValues[lowerIndex] }
        let weight = rank - Double(lowerIndex)
        return sortedValues[lowerIndex] * (1 - weight) + sortedValues[upperIndex] * weight
    }

    /// Creates a distribution from raw values.
    init(values: [Double]) {
        sortedValues = values.sorted()
    }

    /// Creates a distribution from a metric history series.
    init(series: BenchmarkMetricHistorySeries) {
        self.init(values: series.points.map(\.value))
    }

    /// Splits the distribution into `binCount` equal-width buckets between
    /// `minimum` and `maximum`. Returns an empty array when there are fewer than
    /// two distinct values to bin.
    func histogram(binCount: Int = 12) -> [HistogramBin] {
        guard binCount > 0, let minimum, let maximum, maximum > minimum else {
            return []
        }

        let span = maximum - minimum
        let step = span / Double(binCount)
        var bins: [HistogramBin] = (0..<binCount).map { index in
            let lower = minimum + Double(index) * step
            let upper = index == binCount - 1 ? maximum : lower + step
            return HistogramBin(lower: lower, upper: upper, count: 0)
        }

        for value in sortedValues {
            var index = Int(((value - minimum) / step).rounded(.down))
            if index >= binCount { index = binCount - 1 }
            if index < 0 { index = 0 }
            bins[index].count += 1
        }

        return bins
    }
}

struct HistogramBin: Hashable, Identifiable, Sendable {
    var lower: Double
    var upper: Double
    var count: Int

    var id: Double { lower }

    var midpoint: Double { (lower + upper) / 2 }
}
