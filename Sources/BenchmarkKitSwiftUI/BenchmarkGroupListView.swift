import BenchmarkKit
import SwiftUI

struct BenchmarkGroupListView: View {
    let groups: [BenchmarkSuiteGroup]

    @Binding var filters: BenchmarkDashboardFilterState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BenchmarkSectionHeader(
                title: "Groups",
                subtitle: "Select a suite or scenario to narrow the comparison list."
            )

            VStack(spacing: 0) {
                ForEach(groups) { group in
                    BenchmarkSuiteGroupView(group: group, filters: $filters)

                    if group.id != groups.last?.id {
                        Divider()
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary)
            }
        }
    }
}

private struct BenchmarkSuiteGroupView: View {
    let group: BenchmarkSuiteGroup

    @Binding var filters: BenchmarkDashboardFilterState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: selectSuite) {
                BenchmarkGroupRow(
                    title: group.suite.name,
                    subtitle: "\(group.scenarios.count) scenarios",
                    summary: group.summary,
                    isSelected: filters.selectedSuiteID == group.suite.id && filters.selectedScenarioID == nil
                )
            }
            .buttonStyle(.plain)

            VStack(spacing: 0) {
                ForEach(group.scenarios) { scenarioGroup in
                    Button(action: { selectScenario(scenarioGroup.scenario) }) {
                        BenchmarkGroupRow(
                            title: scenarioGroup.scenario.name,
                            subtitle: "\(scenarioGroup.rows.count) metrics",
                            summary: scenarioGroup.summary,
                            isSelected: filters.selectedScenarioID == scenarioGroup.scenario.id
                        )
                        .padding(.leading, 18)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func selectSuite() {
        filters.selectedSuiteID = group.suite.id
        filters.selectedScenarioID = nil
    }

    private func selectScenario(_ scenario: BenchmarkScenario) {
        filters.selectedSuiteID = scenario.suiteID
        filters.selectedScenarioID = scenario.id
    }
}

private struct BenchmarkGroupRow: View {
    let title: String
    let subtitle: String
    let summary: BenchmarkOverviewSummary
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            BenchmarkCompactCounts(summary: summary)
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }
}

private struct BenchmarkCompactCounts: View {
    let summary: BenchmarkOverviewSummary

    var body: some View {
        HStack(spacing: 8) {
            BenchmarkCountPill(title: "R", count: summary.regressedCount, status: .regressed)
            BenchmarkCountPill(title: "I", count: summary.improvedCount, status: .improved)
            BenchmarkCountPill(title: "M", count: summary.missingDataCount, status: .missingBaseline)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Regressed \(summary.regressedCount), improved \(summary.improvedCount), missing \(summary.missingDataCount)")
    }
}

private struct BenchmarkCountPill: View {
    let title: String
    let count: Int
    let status: BenchmarkComparisonStatus

    var body: some View {
        Text("\(title) \(count)")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(BenchmarkStatusStyle.color(for: status).opacity(0.12), in: Capsule())
            .foregroundStyle(BenchmarkStatusStyle.color(for: status))
    }
}
