import BenchmarkKit
import SwiftUI

struct BenchmarkDashboardAdvancedFilterSheet: View {
    let catalog: BenchmarkDashboardCatalog

    @Binding var filters: BenchmarkDashboardFilterState
    @Binding var comparisonMode: BenchmarkDashboardComparisonMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Picker("Mode", selection: $comparisonMode) {
                    ForEach(BenchmarkDashboardComparisonMode.allCases) { mode in
                        Label(mode.menuTitle, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }

                BenchmarkFilterValueRow(
                    title: comparisonMode.menuTitle,
                    subtitle: comparisonMode.subtitle,
                    isSelected: true
                )
            } header: {
                Text("Comparison")
            } footer: {
                Text(
                    "Comparison modes use only comparable scenario shapes so unrelated runs do not share a trend window."
                )
            }

            Section("History") {
                Picker("Archive", selection: $filters.archiveSelection) {
                    ForEach(BenchmarkDashboardArchiveSelection.allCases, id: \.self) { selection in
                        Text(selection.title).tag(selection)
                    }
                }

                Picker("Dates", selection: $filters.dateFilter) {
                    ForEach(BenchmarkDashboardDateFilter.allCases, id: \.self) { dateFilter in
                        Text(dateFilter.title).tag(dateFilter)
                    }
                }

                Picker("State", selection: $filters.statusFilter) {
                    ForEach(BenchmarkDashboardStatusFilter.allCases, id: \.self) { statusFilter in
                        Text(statusFilter.title).tag(statusFilter)
                    }
                }
            }

            if catalog.sortedSuites.isEmpty == false {
                Section("Suite") {
                    Button(action: clearSuite) {
                        BenchmarkFilterValueRow(
                            title: "All Suites",
                            subtitle: nil,
                            isSelected: filters.selectedSuiteID == nil
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(catalog.sortedSuites) { suite in
                        Button(action: { selectSuite(suite) }) {
                            BenchmarkFilterValueRow(
                                title: suite.name,
                                subtitle: nil,
                                isSelected: filters.selectedSuiteID == suite.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if hasScenarioOptions {
                Section("Scenario") {
                    Button(action: clearScenario) {
                        BenchmarkFilterValueRow(
                            title: "All Scenarios",
                            subtitle: nil,
                            isSelected: filters.selectedScenarioID == nil
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(catalog.scenarios(in: filters.selectedSuiteID)) { scenario in
                        Button(action: { selectScenario(scenario) }) {
                            BenchmarkFilterValueRow(
                                title: scenario.name,
                                subtitle: catalog.suite(withID: scenario.suiteID)?.name,
                                isSelected: filters.selectedScenarioID == scenario.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if catalog.sortedMetrics.isEmpty == false {
                Section("Metric") {
                    Button(action: clearMetric) {
                        BenchmarkFilterValueRow(
                            title: "All Metrics",
                            subtitle: nil,
                            isSelected: filters.selectedMetricID == nil
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(catalog.sortedMetrics) { metric in
                        Button(action: { selectMetric(metric) }) {
                            BenchmarkFilterValueRow(
                                title: metric.name,
                                subtitle: metric.unit.description,
                                isSelected: filters.selectedMetricID == metric.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if catalog.allTags.isEmpty == false {
                Section("Tags") {
                    Button(action: clearTags) {
                        BenchmarkFilterValueRow(
                            title: "All Tags",
                            subtitle: nil,
                            isSelected: filters.selectedTagIDs.isEmpty
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(catalog.allTags) { tag in
                        Button(action: { toggleTag(tag) }) {
                            BenchmarkFilterValueRow(
                                title: tag.name,
                                subtitle: nil,
                                isSelected: filters.selectedTagIDs.contains(tag.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Advanced Filters")
        #if os(iOS) || os(tvOS) || os(watchOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Button("Reset", action: resetFilters)
                }
            }
    }

    private var hasScenarioOptions: Bool {
        catalog.scenarios(in: filters.selectedSuiteID).isEmpty == false
    }

    private func selectSuite(_ suite: BenchmarkSuite) {
        filters.selectedSuiteID = suite.id

        if
            let selectedScenarioID = filters.selectedScenarioID,
            catalog.scenario(withID: selectedScenarioID)?.suiteID != suite.id
        {
            filters.selectedScenarioID = nil
        }
    }

    private func clearSuite() {
        filters.selectedSuiteID = nil
    }

    private func selectScenario(_ scenario: BenchmarkScenario) {
        filters.selectedSuiteID = scenario.suiteID
        filters.selectedScenarioID = scenario.id
    }

    private func clearScenario() {
        filters.selectedScenarioID = nil
    }

    private func selectMetric(_ metric: BenchmarkMetric) {
        filters.selectedMetricID = metric.id
    }

    private func clearMetric() {
        filters.selectedMetricID = nil
    }

    private func toggleTag(_ tag: BenchmarkTag) {
        if filters.selectedTagIDs.contains(tag.id) {
            filters.selectedTagIDs.remove(tag.id)
        } else {
            filters.selectedTagIDs.insert(tag.id)
        }
    }

    private func clearTags() {
        filters.selectedTagIDs = []
    }

    private func resetFilters() {
        filters.reset(initialArchiveFilter: .active)
        comparisonMode = .defaultMode
    }
}
