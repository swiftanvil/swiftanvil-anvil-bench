import BenchmarkKit
import SwiftUI

#if canImport(Charts)
import Charts
#endif

struct BenchmarkMetricComparisonChartView: View {
    let row: BenchmarkComparisonRow

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var chartPoints: [BenchmarkMetricComparisonPoint] {
        [
            row.comparison.baseline.mean.map {
                BenchmarkMetricComparisonPoint(scope: .baseline, value: $0, samples: row.comparison.baseline.count)
            },
            row.comparison.current.mean.map {
                BenchmarkMetricComparisonPoint(scope: .current, value: $0, samples: row.comparison.current.count)
            }
        ]
        .compactMap(\.self)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BenchmarkSectionHeader(
                title: "Baseline vs Current",
                subtitle: "Mean values and sample coverage for this metric."
            )

            if chartPoints.isEmpty {
                BenchmarkChartFallbackView(message: "No baseline or current values are available for this metric.")
            } else {
                chartContent
            }
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        #if canImport(Charts)
        Chart(chartPoints) { point in
            BarMark(
                x: .value("Scope", point.scope.title),
                y: .value(row.metric.name, BenchmarkValueFormatter.displayValue(point.value, unit: row.metric.unit))
            )
            .foregroundStyle(by: .value("Scope", point.scope.title))
            .annotation(position: .top, alignment: .center) {
                Text(BenchmarkValueFormatter.value(point.value, unit: row.metric.unit))
                    .font(.caption)
                    .monospacedDigit()
            }
            .accessibilityLabel(point.accessibilityLabel(unit: row.metric.unit))
        }
        .chartYAxisLabel(BenchmarkValueFormatter.unitLabel(row.metric.unit))
        .frame(minHeight: 180)
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

    private var accessibilitySummary: String {
        [
            "Baseline \(BenchmarkValueFormatter.value(row.comparison.baseline.mean, unit: row.metric.unit)) with \(row.comparison.baseline.count) samples",
            "current \(BenchmarkValueFormatter.value(row.comparison.current.mean, unit: row.metric.unit)) with \(row.comparison.current.count) samples",
            "delta \(BenchmarkValueFormatter.delta(row.comparison.delta, unit: row.metric.unit))",
            row.status.title
        ]
        .joined(separator: ", ")
    }
}

private struct BenchmarkMetricComparisonPoint: Identifiable {
    var id: BenchmarkComparisonScope {
        scope
    }

    var scope: BenchmarkComparisonScope
    var value: Double
    var samples: Int

    func accessibilityLabel(unit: BenchmarkMetricUnit) -> String {
        "\(scope.title), \(BenchmarkValueFormatter.value(value, unit: unit)), \(samples) samples"
    }
}
