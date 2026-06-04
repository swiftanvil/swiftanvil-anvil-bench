import BenchmarkKit
import SwiftUI

#if canImport(Charts)
import Charts
#endif

struct BenchmarkTrendChartView: View {
    let row: BenchmarkComparisonRow

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var points: [BenchmarkMetricHistoryPoint] {
        row.history.sortedPoints
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BenchmarkSectionHeader(
                title: "Metric History",
                subtitle: "Ordered samples for baseline and current runs."
            )

            if points.count < 2 {
                BenchmarkChartFallbackView(message: "Metric history needs at least two samples to draw a trend.")
            } else {
                chartContent
            }
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        #if canImport(Charts)
        Chart {
            if let baselineMean = row.comparison.baseline.mean {
                RuleMark(y: .value("Baseline mean", BenchmarkValueFormatter.displayValue(baselineMean, unit: row.metric.unit)))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .accessibilityLabel("Baseline mean \(BenchmarkValueFormatter.value(baselineMean, unit: row.metric.unit))")
            }

            ForEach(points) { point in
                LineMark(
                    x: .value("Measured", point.measuredAt),
                    y: .value(row.metric.name, BenchmarkValueFormatter.displayValue(point.value, unit: row.metric.unit))
                )
                .foregroundStyle(by: .value("Scope", point.scope.title))
                .symbol(by: .value("Scope", point.scope.title))

                PointMark(
                    x: .value("Measured", point.measuredAt),
                    y: .value(row.metric.name, BenchmarkValueFormatter.displayValue(point.value, unit: row.metric.unit))
                )
                .foregroundStyle(by: .value("Scope", point.scope.title))
                .accessibilityLabel(point.accessibilitySummary(unit: row.metric.unit))
            }
        }
        .chartYAxisLabel(BenchmarkValueFormatter.unitLabel(row.metric.unit))
        .frame(minHeight: 220)
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
        let first = points.first
        let latest = points.last

        return [
            "\(row.metric.name) history with \(points.count) samples",
            "trend \(BenchmarkValueFormatter.trendDirection(row.trend.direction))",
            first.map { "first \($0.accessibilitySummary(unit: row.metric.unit))" },
            latest.map { "latest \($0.accessibilitySummary(unit: row.metric.unit))" }
        ]
        .compactMap(\.self)
        .joined(separator: ", ")
    }
}
