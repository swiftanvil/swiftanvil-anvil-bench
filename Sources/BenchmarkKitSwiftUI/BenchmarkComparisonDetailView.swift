import BenchmarkKit
import SwiftUI

/// The **Metric** screen in the Overview → Metric → Comparison → Drill flow.
///
/// Shows the comparison, trend, and distribution charts for a single metric,
/// plus key numbers, confidence, and expandable audit context. The "Compare
/// cohorts" toolbar item pushes the Comparison screen; tapping a sample in the
/// trend chart pushes the Drill screen.
struct BenchmarkComparisonDetailView: View {
    let row: BenchmarkComparisonRow
    var cohorts: [BenchmarkCohort] = []

    @State private var distribution: BenchmarkDistribution

    init(row: BenchmarkComparisonRow, cohorts: [BenchmarkCohort] = []) {
        self.row = row
        self.cohorts = cohorts
        _distribution = State(initialValue: BenchmarkDistribution(series: row.history))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BenchmarkDetailHeader(row: row)
                BenchmarkMetricComparisonChartView(row: row)
                BenchmarkTrendChartView(row: row)
                BenchmarkDistributionChartView(metric: row.metric, distribution: distribution)
                BenchmarkDetailNumbers(row: row)
                BenchmarkConfidenceView(confidence: row.confidence)
                BenchmarkRelatedPerformanceChangeNotesView(notes: row.comparison.relatedPerformanceChangeNotes)
                BenchmarkDetailSamples(row: row)
                BenchmarkDetailDisclosure(
                    title: "Run Context",
                    subtitle: "Baseline and current run metadata.",
                    systemImage: "info.circle"
                ) {
                    BenchmarkDetailContextView(row: row, showsRelatedPerformanceChangeNotes: false)
                }
                BenchmarkDetailDisclosure(
                    title: "Notes",
                    subtitle: "Confidence, missing data, and archive notes.",
                    systemImage: "note.text"
                ) {
                    BenchmarkDetailNotes(row: row)
                }
                BenchmarkExportView(
                    title: "Export",
                    subtitle: "Share this metric detail as a plain text summary.",
                    payload: BenchmarkExportFormatter.summary(for: row)
                )
            }
            .padding()
        }
        .navigationTitle(row.metric.name)
        .toolbar {
            if !cohorts.isEmpty {
                ToolbarItem(placement: .secondaryAction) {
                    NavigationLink(value: BenchmarkComparisonRoute(rowID: row.id)) {
                        Label("Compare cohorts", systemImage: "rectangle.split.2x1")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: BenchmarkExportFormatter.summary(for: row)) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}

/// Route identifier for the Comparison screen. Carries only the comparison row ID
/// so the navigation destination can re-resolve it against current loader state.
struct BenchmarkComparisonRoute: Hashable {
    let rowID: BenchmarkComparisonRow.ID
}

/// Route identifier for the Drill screen.
struct BenchmarkDrillRoute: Hashable {
    let rowID: BenchmarkComparisonRow.ID
    let sampleID: BenchmarkSample.ID
}

private struct BenchmarkDetailHeader: View {
    let row: BenchmarkComparisonRow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BenchmarkStatusBadge(status: row.status)

            Text(row.metric.name)
                .font(.title2.weight(.semibold))

            Text("\(row.suite.name) / \(row.scenario.name)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(
                "Unit: \(BenchmarkValueFormatter.unitLabel(row.metric.unit)) | Direction: \(BenchmarkValueFormatter.direction(row.metric.direction))"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BenchmarkDetailNumbers: View {
    let row: BenchmarkComparisonRow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BenchmarkSectionHeader(title: "Key Numbers", subtitle: "Text summary for the selected comparison.")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading, spacing: 10) {
                BenchmarkValueField(
                    title: "Baseline Mean",
                    value: BenchmarkValueFormatter.value(row.comparison.baseline.mean, unit: row.metric.unit)
                )
                BenchmarkValueField(
                    title: "Current Mean",
                    value: BenchmarkValueFormatter.value(row.comparison.current.mean, unit: row.metric.unit)
                )
                BenchmarkValueField(
                    title: "Absolute Delta",
                    value: BenchmarkValueFormatter.absoluteDelta(row.comparison.delta, unit: row.metric.unit)
                )
                BenchmarkValueField(
                    title: "Percent Delta",
                    value: BenchmarkValueFormatter.percent(row.comparison.delta?.percentage)
                )
                BenchmarkValueField(
                    title: "Latest Run",
                    value: row.latestRunStartedAt.map(BenchmarkValueFormatter.date) ?? "Unavailable"
                )
                BenchmarkValueField(title: "Trend", value: BenchmarkValueFormatter.trendDirection(row.trend.direction))
            }
        }
    }
}

private struct BenchmarkDetailSamples: View {
    let row: BenchmarkComparisonRow

    var body: some View {
        BenchmarkDetailDisclosure(
            title: "Sample Counts",
            subtitle: "Raw baseline, current, and trend counts.",
            systemImage: "number"
        ) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], alignment: .leading, spacing: 10) {
                BenchmarkValueField(title: "Baseline Samples", value: "\(row.comparison.baseline.count)")
                BenchmarkValueField(title: "Current Samples", value: "\(row.comparison.current.count)")
                BenchmarkValueField(title: "Trend Samples", value: "\(row.trend.sampleCount)")
            }
        }
    }
}

private struct BenchmarkDetailDisclosure<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        DisclosureGroup {
            content
                .padding(.top, 12)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
    }
}

private struct BenchmarkDetailNotes: View {
    let row: BenchmarkComparisonRow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if row.notes.isEmpty {
                Text("No additional notes for this comparison.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(row.notes, id: \.self) { note in
                    Label(note, systemImage: "note.text")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
