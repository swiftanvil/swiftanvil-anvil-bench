import BenchmarkKit
import SwiftUI

#if canImport(Charts)
import Charts
#endif

struct BenchmarkMetricKeyNumbersRow: View {
    let row: BenchmarkComparisonRow

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                BenchmarkDetailNumberCard(title: "Baseline", value: BenchmarkValueFormatter.value(row.comparison.baseline.mean, unit: row.metric.unit))
                BenchmarkDetailNumberCard(title: "Current", value: BenchmarkValueFormatter.value(row.comparison.current.mean, unit: row.metric.unit))
                BenchmarkDetailNumberCard(title: "Delta", value: BenchmarkValueFormatter.absoluteDelta(row.comparison.delta, unit: row.metric.unit))
                BenchmarkDetailNumberCard(title: "Change", value: BenchmarkValueFormatter.percent(row.comparison.delta?.percentage))
                BenchmarkDetailNumberCard(title: "Samples", value: "\(row.comparison.current.count)")
                BenchmarkDetailNumberCard(title: "Latest Run", value: row.latestRunStartedAt.map(BenchmarkValueFormatter.date) ?? "Unavailable")
            }
            .padding(.horizontal, 1)
        }
    }
}

struct BenchmarkDetailNumberCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .lineLimit(2)
        }
        .frame(width: 168, alignment: .leading)
        .frame(minHeight: 82, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.quaternary)
        }
    }
}

struct BenchmarkMetricSparkline: View {
    let row: BenchmarkComparisonRow
    var fixedHeight: CGFloat = 120

    private var points: [BenchmarkMetricHistoryPoint] {
        row.history.sortedPoints
    }

    var body: some View {
        #if canImport(Charts)
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Measured", point.measuredAt),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(by: .value("Scope", point.scope.title))

                PointMark(
                    x: .value("Measured", point.measuredAt),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(by: .value("Scope", point.scope.title))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
        }
        .chartLegend(.hidden)
        .frame(height: fixedHeight)
        #else
        BenchmarkChartFallbackView(message: "Charts unavailable.")
        #endif
    }
}

struct BenchmarkNotesPanel: View {
    let row: BenchmarkComparisonRow

    var body: some View {
        if row.notes.isEmpty {
            Text("No additional notes for this metric.")
                .font(.body)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(row.notes, id: \.self) { note in
                    Label(note, systemImage: "note.text")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

enum BenchmarkMetricTitleFormatter {
    static func contextualTitle(metricName: String, scenarioName: String) -> String {
        let exactScenarioRemoved = removingPrefix(metricName, prefix: scenarioName)
        if exactScenarioRemoved != metricName {
            return exactScenarioRemoved
        }

        let scenarioWords = scenarioName.split(separator: " ").map(String.init)
        if scenarioWords.count > 1 {
            let nounPhrase = scenarioWords.dropFirst().joined(separator: " ")
            let nounPhraseRemoved = removingPrefix(metricName, prefix: nounPhrase)
            if nounPhraseRemoved != metricName {
                return nounPhraseRemoved
            }
        }

        return metricName
    }

    private static func removingPrefix(_ value: String, prefix: String) -> String {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPrefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedPrefix.isEmpty == false else {
            return normalizedValue
        }

        if normalizedValue.hasPrefix(normalizedPrefix) {
            let startIndex = normalizedValue.index(normalizedValue.startIndex, offsetBy: normalizedPrefix.count)
            let trimmed = normalizedValue[startIndex...]
                .trimmingCharacters(in: CharacterSet(charactersIn: " -:"))
            return trimmed.isEmpty ? normalizedValue : trimmed
        }

        return normalizedValue
    }
}
