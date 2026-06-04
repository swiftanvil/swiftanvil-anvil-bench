import BenchmarkKit
import SwiftUI

struct BenchmarkSuiteDetailScreen: View {
    let suiteGroup: BenchmarkSuiteGroup

    @State private var selectedScenarioID: BenchmarkScenario.ID?
    @State private var isScenarioListExpanded = true
    @State private var isMetricsExpanded = true
    @State private var isChartExpanded = true

    private var selectedScenarioGroup: BenchmarkScenarioGroup? {
        let fallback = suiteGroup.scenarios.first
        guard let selectedScenarioID else { return fallback }
        return suiteGroup.scenarios.first(where: { $0.scenario.id == selectedScenarioID }) ?? fallback
    }

    private var heroMetricRow: BenchmarkComparisonRow? {
        selectedScenarioGroup?.rows.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BenchmarkDisclosureSection(
                    title: "Scenarios",
                    subtitle: "Latest scenarios first. The newest observed scenario is selected automatically.",
                    isExpanded: $isScenarioListExpanded
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(suiteGroup.scenarios) { scenarioGroup in
                                Button {
                                    selectedScenarioID = scenarioGroup.scenario.id
                                } label: {
                                    BenchmarkScenarioSelectionCard(
                                        scenarioGroup: scenarioGroup,
                                        isSelected: scenarioGroup.scenario.id == selectedScenarioGroup?.scenario.id
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                    .frame(maxWidth: .infinity)
                }

                if let selectedScenarioGroup {
                    BenchmarkDisclosureSection(
                        title: "Metrics",
                        subtitle: "Tap a metric card to open scenario details and swipe through all metrics there.",
                        isExpanded: $isMetricsExpanded
                    ) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(selectedScenarioGroup.rows) { row in
                                    NavigationLink(
                                        value: BenchmarkScenarioRoute(
                                            suite: suiteGroup.suite,
                                            scenario: selectedScenarioGroup.scenario,
                                            metricID: row.metric.id
                                        )
                                    ) {
                                        BenchmarkMetricCarouselCard(row: row)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if let heroMetricRow {
                        BenchmarkDisclosureSection(
                            title: "Primary Metric",
                            subtitle: "A graph-first view of the highest-priority metric for the selected scenario.",
                            isExpanded: $isChartExpanded
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                BenchmarkMetricHeroCard(row: heroMetricRow)
                                BenchmarkTrendChartView(row: heroMetricRow)
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(suiteGroup.suite.name)
#if os(iOS) || os(tvOS) || os(watchOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .task {
            if selectedScenarioID == nil {
                selectedScenarioID = suiteGroup.scenarios.first?.scenario.id
            }
        }
    }
}
