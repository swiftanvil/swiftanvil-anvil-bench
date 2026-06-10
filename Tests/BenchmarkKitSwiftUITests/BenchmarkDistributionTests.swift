import BenchmarkKit
import Testing
@testable import BenchmarkKitSwiftUI

@Suite("BenchmarkDistribution")
struct BenchmarkDistributionTests {
    @Test("Percentiles interpolate linearly between sorted samples")
    func percentilesInterpolateLinearly() {
        let distribution = BenchmarkDistribution(values: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])

        #expect(distribution.minimum == 1)
        #expect(distribution.maximum == 10)
        #expect(distribution.p50 == 5.5)
        #expect(distribution.p95 != nil)
        if let p95 = distribution.p95 {
            #expect(abs(p95 - 9.55) < 0.001)
        }
        if let p99 = distribution.p99 {
            #expect(abs(p99 - 9.91) < 0.001)
        }
    }

    @Test("Single sample distribution returns the sample for every percentile")
    func singleSampleDistribution() {
        let distribution = BenchmarkDistribution(values: [42])

        #expect(distribution.count == 1)
        #expect(distribution.p50 == 42)
        #expect(distribution.p95 == 42)
        #expect(distribution.p99 == 42)
        #expect(distribution.hasEnoughSamplesForPercentiles == false)
    }

    @Test("Empty distribution returns nil for every accessor")
    func emptyDistribution() {
        let distribution = BenchmarkDistribution(values: [])

        #expect(distribution.count == 0)
        #expect(distribution.minimum == nil)
        #expect(distribution.maximum == nil)
        #expect(distribution.p50 == nil)
        #expect(distribution.p95 == nil)
        #expect(distribution.p99 == nil)
        #expect(distribution.histogram().isEmpty)
    }

    @Test("Histogram bins partition the value range and account for every sample")
    func histogramBinsAccountForEverySample() {
        let values = [0.0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let distribution = BenchmarkDistribution(values: values)

        let bins = distribution.histogram(binCount: 5)

        #expect(bins.count == 5)
        #expect(bins.reduce(0) { $0 + $1.count } == values.count)
        // Lower bound of bin 0 is the minimum; upper bound of last bin is the maximum.
        #expect(bins.first?.lower == 0)
        #expect(bins.last?.upper == 10)
    }

    @Test("Percentile clamps to [0, 1]")
    func percentileClamps() {
        let distribution = BenchmarkDistribution(values: [1, 2, 3, 4, 5])

        #expect(distribution.percentile(-1) == 1)
        #expect(distribution.percentile(2) == 5)
    }
}

@Suite("BenchmarkValueFormatter")
struct BenchmarkValueFormatterTests {
    @Test("Millisecond values display as seconds with two decimals")
    func millisecondValuesDisplayAsSeconds() {
        let formatted = BenchmarkValueFormatter.value(1234.5, unit: .milliseconds)

        #expect(formatted == "1.23 s")
        #expect(BenchmarkValueFormatter.absoluteDelta(
            BenchmarkDelta(baseline: 2000, current: 1500),
            unit: .milliseconds
        ) == "-0.50 s")
        #expect(BenchmarkValueFormatter.unitLabel(.milliseconds) == "s")
        #expect(BenchmarkValueFormatter.displayValue(2500, unit: .milliseconds) == 2.5)
    }

    @Test("Nil value formats as Unavailable")
    func nilValueFormatsAsUnavailable() {
        #expect(BenchmarkValueFormatter.value(nil, unit: .milliseconds) == "Unavailable")
        #expect(BenchmarkValueFormatter.percent(nil) == "Unavailable")
        #expect(BenchmarkValueFormatter.delta(nil, unit: .milliseconds) == "Unavailable")
    }

    @Test("Signed deltas include their sign")
    func signedDeltasIncludeSign() {
        let positive = BenchmarkDelta(baseline: 100, current: 110)
        let negative = BenchmarkDelta(baseline: 100, current: 90)

        #expect(BenchmarkValueFormatter.absoluteDelta(positive, unit: .seconds) == "+10.00 s")
        #expect(BenchmarkValueFormatter.absoluteDelta(negative, unit: .seconds) == "-10.00 s")
        #expect(BenchmarkValueFormatter.percent(positive.percentage) == "+10.00%")
    }

    @Test("Byte values format as rounded megabytes")
    func byteValuesFormatAsRoundedMegabytes() {
        let oneAndHalfMB = 1_572_864.0
        let eightGB = 8_589_934_592.0
        let positiveDelta = BenchmarkDelta(baseline: eightGB, current: eightGB + 1_048_576)
        let negativeDelta = BenchmarkDelta(baseline: eightGB, current: eightGB - 1_048_576)

        #expect(BenchmarkValueFormatter.value(oneAndHalfMB, unit: .bytes) == "2 MB")
        #expect(BenchmarkValueFormatter.value(eightGB, unit: .bytes) == "8192 MB")
        #expect(BenchmarkValueFormatter.absoluteDelta(positiveDelta, unit: .bytes) == "+1 MB")
        #expect(BenchmarkValueFormatter.absoluteDelta(negativeDelta, unit: .bytes) == "-1 MB")
        #expect(BenchmarkValueFormatter.unitLabel(.bytes) == "MB")
        #expect(BenchmarkValueFormatter.displayValue(eightGB, unit: .bytes) == 8192)
    }

    @Test("Percentile labels include the rank")
    func percentileLabelsIncludeTheRank() {
        let formatted = BenchmarkValueFormatter.percentile(95, value: 1.5, unit: .seconds)

        #expect(formatted.contains("p95"))
        #expect(formatted.contains("1.50"))
    }
}
