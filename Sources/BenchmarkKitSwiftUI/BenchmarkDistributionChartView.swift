import BenchmarkKit
import SwiftUI

#if canImport(Charts)
    import Charts
#endif

/// Distribution histogram with p95 / p99 markers for a metric's captured samples.
///
/// Mandatory on the Metric and Drill screens per the dashboard IA: a percentile
/// readout alone hides bimodality and fat-tailed distributions.
struct BenchmarkDistributionChartView: View {
    let metric: BenchmarkMetric
    let distribution: BenchmarkDistribution

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BenchmarkSectionHeader(
                title: "Distribution",
                subtitle: "Sample-count histogram with p95 and p99 markers."
            )

            if distribution.count == 0 {
                BenchmarkChartFallbackView(
                    message: "No samples match this filter."
                )
            } else if !distribution.hasEnoughSamplesForPercentiles {
                rawValueTable
            } else {
                chartContent
                percentileLegend
            }
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        let bins = distribution.histogram()

        #if canImport(Charts)
            Chart {
                ForEach(bins) { bin in
                    BarMark(
                        x: .value("Bucket", BenchmarkValueFormatter.displayValue(bin.midpoint, unit: metric.unit)),
                        y: .value("Count", bin.count)
                    )
                    .foregroundStyle(.tint.opacity(0.6))
                    .accessibilityLabel(binAccessibilityLabel(for: bin))
                }

                if let p95 = distribution.p95 {
                    RuleMark(x: .value("p95", BenchmarkValueFormatter.displayValue(p95, unit: metric.unit)))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .annotation(position: .top, alignment: .leading) {
                            Text("p95")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                }

                if let p99 = distribution.p99 {
                    RuleMark(x: .value("p99", BenchmarkValueFormatter.displayValue(p99, unit: metric.unit)))
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("p99")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                }
            }
            .chartXAxisLabel(BenchmarkValueFormatter.unitLabel(metric.unit))
            .chartYAxisLabel("count")
            .frame(minHeight: 200)
            .padding(12)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary)
            }
            .transaction { transaction in
                if reduceMotion {
                    transaction.animation = nil
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
        #else
            BenchmarkChartFallbackView(message: accessibilitySummary)
        #endif
    }

    private var percentileLegend: some View {
        HStack(spacing: 14) {
            BenchmarkPercentilePill(label: "p50", value: distribution.p50, unit: metric.unit, tint: .secondary)
            BenchmarkPercentilePill(label: "p95", value: distribution.p95, unit: metric.unit, tint: .orange)
            BenchmarkPercentilePill(label: "p99", value: distribution.p99, unit: metric.unit, tint: .red)
            Spacer(minLength: 0)
        }
        .font(.caption.monospacedDigit())
    }

    private var rawValueTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sample size below percentile threshold (\(distribution.count) of 5). Showing raw values.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(distribution.sortedValues.indices, id: \.self) { index in
                Text(BenchmarkValueFormatter.value(distribution.sortedValues[index], unit: metric.unit))
                    .font(.subheadline.monospacedDigit())
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
    }

    private var accessibilitySummary: String {
        [
            "Distribution of \(distribution.count) samples",
            "p50 \(BenchmarkValueFormatter.value(distribution.p50, unit: metric.unit))",
            "p95 \(BenchmarkValueFormatter.value(distribution.p95, unit: metric.unit))",
            "p99 \(BenchmarkValueFormatter.value(distribution.p99, unit: metric.unit))"
        ]
        .joined(separator: ", ")
    }

    private func binAccessibilityLabel(for bin: HistogramBin) -> String {
        let lower = BenchmarkValueFormatter.value(bin.lower, unit: metric.unit)
        let upper = BenchmarkValueFormatter.value(bin.upper, unit: metric.unit)
        return "\(bin.count) samples between \(lower) and \(upper)"
    }
}

private struct BenchmarkPercentilePill: View {
    let label: String
    let value: Double?
    let unit: BenchmarkMetricUnit
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(tint)
                .fontWeight(.semibold)
            Text(BenchmarkValueFormatter.value(value, unit: unit))
                .foregroundStyle(.primary)
        }
    }
}
