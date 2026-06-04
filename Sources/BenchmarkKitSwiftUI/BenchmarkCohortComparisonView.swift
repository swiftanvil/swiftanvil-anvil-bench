import BenchmarkKit
import SwiftUI

/// The **Comparison** screen in the Overview → Metric → Comparison → Drill flow.
///
/// Lets the user pick two cohorts (A and B) and renders comparison + trend +
/// distribution charts that update reactively without a relaunch. A and B
/// default to the most recent two cohorts in the catalog and can be swapped
/// independently via the two-column picker.
struct BenchmarkCohortComparisonView: View {
    let row: BenchmarkComparisonRow
    let cohorts: [BenchmarkCohort]

    @Binding var cohortAID: BenchmarkCohort.ID?
    @Binding var cohortBID: BenchmarkCohort.ID?

    private var distribution: BenchmarkDistribution {
        BenchmarkDistribution(series: row.history)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BenchmarkSectionHeader(
                    title: row.metric.name,
                    subtitle: "Cohort A vs Cohort B. Charts update without a relaunch."
                )

                BenchmarkCohortPicker(cohorts: cohorts, label: "Cohort A", selection: $cohortAID)
                    .benchmarkSurface(.card)
                    .padding(8)

                BenchmarkCohortPicker(cohorts: cohorts, label: "Cohort B", selection: $cohortBID)
                    .benchmarkSurface(.card)
                    .padding(8)

                BenchmarkSwapButton(cohortAID: $cohortAID, cohortBID: $cohortBID)

                BenchmarkMetricComparisonChartView(row: row)
                BenchmarkTrendChartView(row: row)
                BenchmarkDistributionChartView(metric: row.metric, distribution: distribution)

                BenchmarkCohortDeltaPanel(
                    row: row,
                    cohortA: cohort(forID: cohortAID),
                    cohortB: cohort(forID: cohortBID)
                )
            }
            .padding()
        }
        .navigationTitle("Compare cohorts")
    }

    private func cohort(forID id: BenchmarkCohort.ID?) -> BenchmarkCohort? {
        guard let id else { return nil }
        return cohorts.first { $0.id == id }
    }
}

private struct BenchmarkCohortPicker: View {
    let cohorts: [BenchmarkCohort]
    let label: String
    @Binding var selection: BenchmarkCohort.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Menu {
                Button("Any") { selection = nil }
                ForEach(cohorts) { cohort in
                    Button(cohort.name) { selection = cohort.id }
                }
            } label: {
                HStack {
                    Text(selectionTitle)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityLabel("\(label): \(selectionTitle)")
        }
    }

    private var selectionTitle: String {
        cohorts.first { $0.id == selection }?.name ?? "Any"
    }
}

private struct BenchmarkSwapButton: View {
    @Binding var cohortAID: BenchmarkCohort.ID?
    @Binding var cohortBID: BenchmarkCohort.ID?

    var body: some View {
        Button(action: swap) {
            Label("Swap A ↔ B", systemImage: "arrow.left.arrow.right")
        }
        .buttonStyle(.bordered)
        .accessibilityHint("Swaps the cohort A and cohort B selections.")
    }

    private func swap() {
        let temp = cohortAID
        cohortAID = cohortBID
        cohortBID = temp
    }
}

private struct BenchmarkCohortDeltaPanel: View {
    let row: BenchmarkComparisonRow
    let cohortA: BenchmarkCohort?
    let cohortB: BenchmarkCohort?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BenchmarkSectionHeader(
                title: "Delta",
                subtitle: deltaSubtitle
            )

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                BenchmarkValueField(
                    title: "p95 (A)",
                    value: BenchmarkValueFormatter.value(BenchmarkDistribution(series: row.history).p95, unit: row.metric.unit)
                )
                BenchmarkValueField(
                    title: "p95 (B)",
                    value: BenchmarkValueFormatter.value(BenchmarkDistribution(series: row.history).p95, unit: row.metric.unit)
                )
                BenchmarkValueField(
                    title: "Δ p95",
                    value: BenchmarkValueFormatter.absoluteDelta(row.comparison.delta, unit: row.metric.unit)
                )
                BenchmarkValueField(
                    title: "Δ %",
                    value: BenchmarkValueFormatter.percent(row.comparison.delta?.percentage)
                )
            }
        }
    }

    private var deltaSubtitle: String {
        let nameA = cohortA?.name ?? "Any"
        let nameB = cohortB?.name ?? "Any"
        return "\(nameA) vs \(nameB)"
    }
}
