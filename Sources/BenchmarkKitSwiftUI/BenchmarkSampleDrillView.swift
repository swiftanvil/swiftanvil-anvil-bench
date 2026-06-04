import BenchmarkKit
import SwiftUI

/// The **Drill** screen in the Overview → Metric → Comparison → Drill flow.
///
/// Shows a single captured sample: its scope, measured value, run identifier,
/// and a "neighbours" strip of other samples in the same series within ±5 of
/// the selected sample's position. Read-only in v1 per the IA's open question.
struct BenchmarkSampleDrillView: View {
    let row: BenchmarkComparisonRow
    let sample: BenchmarkMetricHistoryPoint

    private var neighbours: [BenchmarkMetricHistoryPoint] {
        let sorted = row.history.sortedPoints
        guard let index = sorted.firstIndex(of: sample) else { return [] }
        let lower = max(0, index - 5)
        let upper = min(sorted.count, index + 6)
        return Array(sorted[lower..<upper])
    }

    private var sampleMatrixContext: BenchmarkRunMatrixContext? {
        row.matrixContexts.first {
            $0.runID == sample.runID && $0.scope == sample.scope
        }
    }

    private var exportPayload: String {
        [
            "Benchmark sample export",
            "\(row.suite.name) / \(row.scenario.name) / \(row.metric.name)",
            "Scope: \(sample.scope.title)",
            "Value: \(BenchmarkValueFormatter.value(sample.value, unit: row.metric.unit))",
            "Measured: \(BenchmarkValueFormatter.date(sample.measuredAt))",
            "Run ID: \(sample.runID.rawValue)",
            "Sample ID: \(sample.id.rawValue)",
            sample.contextSummary.map { "Context: \($0)" },
            sampleMatrixContext.map { "Matrix context: \($0.summary), \($0.archiveState.rawValue)" },
            "Metric summary:",
            BenchmarkExportFormatter.summary(for: row)
        ]
        .compactMap(\.self)
        .joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BenchmarkSectionHeader(
                    title: "Sample",
                    subtitle: BenchmarkValueFormatter.date(sample.measuredAt)
                )

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    BenchmarkValueField(title: "Metric", value: row.metric.name)
                    BenchmarkValueField(title: "Scope", value: sample.scope.title)
                    BenchmarkValueField(title: "Value", value: BenchmarkValueFormatter.value(sample.value, unit: row.metric.unit))
                    BenchmarkValueField(title: "Run ID", value: sample.runID.rawValue)
                    BenchmarkValueField(title: "Sample ID", value: sample.id.rawValue)
                    if let context = sample.contextSummary {
                        BenchmarkValueField(title: "Context", value: context)
                    }
                }

                BenchmarkSectionHeader(
                    title: "Run Matrix",
                    subtitle: "Audit metadata for the run that produced this sample."
                )

                if let sampleMatrixContext {
                    BenchmarkSampleMatrixContextCard(context: sampleMatrixContext)
                } else {
                    Text("No matrix context is available for this sample.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                BenchmarkSectionHeader(
                    title: "Neighbours",
                    subtitle: "Adjacent samples in this metric's history."
                )

                VStack(spacing: 8) {
                    ForEach(neighbours) { neighbour in
                        BenchmarkNeighbourRow(point: neighbour, metric: row.metric, isFocus: neighbour == sample)
                    }
                }

                BenchmarkExportView(
                    title: "Export Sample",
                    subtitle: "Share this sample with its run matrix and metric context.",
                    payload: exportPayload
                )
            }
            .padding()
        }
        .navigationTitle("Drill")
    }
}

private struct BenchmarkSampleMatrixContextCard: View {
    let context: BenchmarkRunMatrixContext

    private var metadataPairs: [(key: String, value: String)] {
        context.metadata
            .map { (key: $0.key, value: $0.value) }
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(context.scope.title)
                    .font(.subheadline.weight(.semibold))
                Text(BenchmarkValueFormatter.date(context.startedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(context.archiveState.rawValue.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(context.summary)
                .font(.body)
                .foregroundStyle(.secondary)

            if metadataPairs.isEmpty == false {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 140), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(metadataPairs, id: \.key) { pair in
                        BenchmarkValueField(title: pair.key, value: pair.value)
                    }
                }
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BenchmarkNeighbourRow: View {
    let point: BenchmarkMetricHistoryPoint
    let metric: BenchmarkMetric
    let isFocus: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: isFocus ? "circle.inset.filled" : "circle")
                .foregroundStyle(isFocus ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(BenchmarkValueFormatter.value(point.value, unit: metric.unit))
                    .font(.subheadline.monospacedDigit())
                Text(BenchmarkValueFormatter.date(point.measuredAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(point.scope.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocus ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isFocus ? 1.5 : 1)
        }
    }
}
