import BenchmarkKit
import SwiftUI

struct BenchmarkDashboardReachabilityDestination: View {
    let route: BenchmarkDashboardReachabilityRoute
    let loadedState: BenchmarkDashboardLoadedState
    let insightEvaluationPolicy: BenchmarkInsightEvaluationPolicy
    let initialArchiveFilter: BenchmarkArchiveFilter
    let retry: () -> Void
    let presentResetHistory: () -> Void

    @Binding var filters: BenchmarkDashboardFilterState

    init(
        route: BenchmarkDashboardReachabilityRoute,
        loadedState: BenchmarkDashboardLoadedState,
        insightEvaluationPolicy: BenchmarkInsightEvaluationPolicy,
        filters: Binding<BenchmarkDashboardFilterState>,
        initialArchiveFilter: BenchmarkArchiveFilter,
        retry: @escaping () -> Void,
        presentResetHistory: @escaping () -> Void
    ) {
        self.route = route
        self.loadedState = loadedState
        self.insightEvaluationPolicy = insightEvaluationPolicy
        _filters = filters
        self.initialArchiveFilter = initialArchiveFilter
        self.retry = retry
        self.presentResetHistory = presentResetHistory
    }

    var body: some View {
        Group {
            switch route {
            case .auditMatrix:
                BenchmarkDashboardAuditMatrixView(rows: loadedState.rows)
            case .sampleIndex:
                BenchmarkDashboardSampleIndexView(rows: loadedState.rows)
            case .exportCenter:
                BenchmarkDashboardExportCenterView(rows: loadedState.rows)
            case .debugControls:
                BenchmarkDashboardDebugControlsView(
                    loadedState: loadedState,
                    insightEvaluationPolicy: insightEvaluationPolicy,
                    initialArchiveFilter: initialArchiveFilter,
                    retry: retry,
                    presentResetHistory: presentResetHistory,
                    filters: $filters
                )
            }
        }
        .navigationTitle(route.title)
    }
}

private struct BenchmarkDashboardAuditMatrixView: View {
    let rows: [BenchmarkComparisonRow]

    var body: some View {
        List(rows) { row in
            NavigationLink(value: row.id) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.metric.name)
                            .font(.headline)
                        Spacer(minLength: 8)
                        BenchmarkStatusBadge(status: row.status)
                    }

                    Text("\(row.suite.name) / \(row.scenario.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    BenchmarkAuditMetadataSummary(row: row)
                }
                .padding(.vertical, 6)
            }
        }
    }
}

private struct BenchmarkDashboardSampleIndexView: View {
    let rows: [BenchmarkComparisonRow]

    var body: some View {
        List {
            ForEach(rows) { row in
                Section {
                    ForEach(row.history.sortedPoints) { point in
                        NavigationLink(value: BenchmarkDrillRoute(rowID: row.id, sampleID: point.id)) {
                            BenchmarkSampleIndexRow(row: row, point: point)
                        }
                    }
                } header: {
                    Text("\(row.scenario.name) / \(row.metric.name)")
                }
            }
        }
    }
}

private struct BenchmarkDashboardExportCenterView: View {
    let rows: [BenchmarkComparisonRow]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BenchmarkExportView(
                    title: "Visible Comparisons",
                    subtitle: "Share the current filtered dashboard as a plain text summary.",
                    payload: BenchmarkExportFormatter.summary(for: rows)
                )

                BenchmarkSectionHeader(
                    title: "Metric Exports",
                    subtitle: "Open any metric to inspect charts, metadata, samples, and its dedicated export."
                )

                LazyVStack(spacing: 12) {
                    ForEach(rows) { row in
                        NavigationLink(value: row.id) {
                            BenchmarkExportMetricRow(row: row)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }
}

private struct BenchmarkDashboardDebugControlsView: View {
    let loadedState: BenchmarkDashboardLoadedState
    let insightEvaluationPolicy: BenchmarkInsightEvaluationPolicy
    let initialArchiveFilter: BenchmarkArchiveFilter
    let retry: () -> Void
    let presentResetHistory: () -> Void

    @Binding var filters: BenchmarkDashboardFilterState

    @State private var dismissedInsightID: BenchmarkComparisonRow.ID?

    private var currentInsight: BenchmarkDashboardInsight? {
        let evaluator = BenchmarkInsightEvaluator(policy: insightEvaluationPolicy)
        guard let insight = evaluator.visibleInsight(for: loadedState.rows.map(\.comparison)),
              let row = loadedState.rows.first(where: { $0.comparison == insight.comparison }),
              dismissedInsightID != row.id
        else {
            return nil
        }

        return BenchmarkDashboardInsight(row: row, insight: insight)
    }

    var body: some View {
        Form {
            if let currentInsight {
                Section("Post-Run Insight") {
                    BenchmarkInsightCard(
                        row: currentInsight.row,
                        insight: currentInsight.insight,
                        dismiss: dismissCurrentInsight
                    )
                }
            }

            Section("Current Scope") {
                LabeledContent("Visible comparisons", value: "\(loadedState.rows.count)")
                LabeledContent("Archive", value: filters.archiveSelection.title)
                LabeledContent("Dates", value: filters.dateFilter.title)
                LabeledContent("State", value: filters.statusFilter.title)
                LabeledContent("Metadata filters", value: "\(filters.selectedComparisonDimensionValues.count)")
                LabeledContent("Tags", value: "\(filters.selectedTagIDs.count)")
            }

            Section("Debug Actions") {
                Button("Reload", systemImage: "arrow.clockwise", action: retry)
                Button("Reset Filters", systemImage: "line.3.horizontal.decrease.circle") {
                    filters.reset(initialArchiveFilter: initialArchiveFilter)
                }
                Button("Delete History", systemImage: "trash", role: .destructive, action: presentResetHistory)
            }
        }
    }

    private func dismissCurrentInsight() {
        dismissedInsightID = currentInsight?.row.id
    }
}

private struct BenchmarkDashboardInsight: Hashable {
    var row: BenchmarkComparisonRow
    var insight: BenchmarkComparisonInsight
}

private struct BenchmarkAuditMetadataSummary: View {
    let row: BenchmarkComparisonRow

    private var metadataKeys: [String] {
        Array(Set(row.matrixContexts.flatMap { $0.metadata.keys }))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("\(row.matrixContexts.count) matrix context\(row.matrixContexts.count == 1 ? "" : "s")", systemImage: "tablecells")
                .font(.caption)
                .foregroundStyle(.secondary)

            if metadataKeys.isEmpty {
                Text("No metadata keys")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Metadata: \(metadataKeys.prefix(6).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

private struct BenchmarkSampleIndexRow: View {
    let row: BenchmarkComparisonRow
    let point: BenchmarkMetricHistoryPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(BenchmarkValueFormatter.value(point.value, unit: row.metric.unit))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                Spacer(minLength: 8)
                Text(point.scope.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(BenchmarkValueFormatter.date(point.measuredAt))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let contextSummary = point.contextSummary {
                Text(contextSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct BenchmarkExportMetricRow: View {
    let row: BenchmarkComparisonRow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.metric.name)
                    .font(.headline)
                Spacer(minLength: 8)
                BenchmarkStatusBadge(status: row.status)
            }

            Text("\(row.suite.name) / \(row.scenario.name)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(row.totalSamples) samples | \(row.matrixContexts.count) matrix contexts")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
    }
}
