import BenchmarkKit
import SwiftUI

struct BenchmarkScenarioDetailScreen: View {
    let scenarioGroup: BenchmarkScenarioGroup
    let initialMetricID: BenchmarkMetric.ID?
    @Binding var filters: BenchmarkDashboardFilterState

    @State private var selectedMetricID: BenchmarkMetric.ID?
    @State private var isFilterSheetPresented = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(scenarioGroup.rows) { row in
                        Button {
                            selectedMetricID = row.metric.id
                        } label: {
                            metricSelectionLabel(for: row)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }
            .frame(maxWidth: .infinity)

            if activeFilterValues.isEmpty == false {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(activeFilterValues) { filterValue in
                            BenchmarkActiveFilterPill(
                                title: filterValue.dimensionTitle,
                                valueTitle: filterValue.title
                            ) {
                                clearFilterOption(filterValue.dimension)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                .frame(maxWidth: .infinity)
            }

            TabView(selection: selectedMetricBinding) {
                ForEach(scenarioGroup.rows) { row in
                    BenchmarkScenarioMetricDetailPage(
                        row: row,
                        metricTitle: contextualMetricTitle(for: row)
                    )
                    .tag(row.metric.id)
                }
            }
            #if os(iOS) || os(tvOS) || os(watchOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle(scenarioGroup.scenario.name)
        #if os(iOS) || os(tvOS) || os(watchOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                if scenarioGroup.comparisonDimensions.isEmpty == false {
                    ToolbarItem(placement: .automatic) {
                        Button("Filter") {
                            isFilterSheetPresented = true
                        }
                    }
                }
            }
            .sheet(isPresented: $isFilterSheetPresented) {
                NavigationStack {
                    BenchmarkScenarioFilterSheet(
                        dimensions: scenarioGroup.comparisonDimensions,
                        selectedComparisonDimensionValues: $filters.selectedComparisonDimensionValues
                    )
                }
                .presentationDetents([.medium, .large])
            }
            .task {
                if selectedMetricID == nil {
                    selectedMetricID = initialMetricID ??
                        persistedMetricID ??
                        scenarioGroup.rows.first?.metric.id
                }
            }
            .onChange(of: selectedMetricID) { newValue in
                guard let newValue else { return }
                UserDefaults.standard.set(newValue.rawValue, forKey: persistedMetricDefaultsKey)
            }
            .onChange(of: scenarioGroup.rows.map(\.metric.id)) { newMetricIDs in
                guard
                    let selectedMetricID,
                    newMetricIDs.contains(selectedMetricID) == false
                else { return }
                self.selectedMetricID = scenarioGroup.rows.first?.metric.id
            }
    }

    private var selectedMetricBinding: Binding<BenchmarkMetric.ID> {
        Binding {
            selectedMetricID ?? scenarioGroup.rows.first!.metric.id
        } set: { newValue in
            selectedMetricID = newValue
        }
    }

    private var persistedMetricDefaultsKey: String {
        "benchmark.dashboard.selectedMetric.\(scenarioGroup.scenario.id.rawValue)"
    }

    private var persistedMetricID: BenchmarkMetric.ID? {
        guard let rawValue = UserDefaults.standard.string(forKey: persistedMetricDefaultsKey) else {
            return nil
        }

        let metricID = BenchmarkMetric.ID(rawValue)
        return scenarioGroup.rows.contains(where: { $0.metric.id == metricID }) ? metricID : nil
    }

    private func contextualMetricTitle(for row: BenchmarkComparisonRow) -> String {
        BenchmarkMetricTitleFormatter.contextualTitle(
            metricName: row.metric.name,
            scenarioName: scenarioGroup.scenario.name
        )
    }

    private func metricSelectionLabel(for row: BenchmarkComparisonRow) -> some View {
        let title = contextualMetricTitle(for: row)
        let value = BenchmarkValueFormatter.value(row.comparison.current.mean, unit: row.metric.unit)

        return BenchmarkMetricSelectionPill(
            title: title,
            value: value,
            isSelected: row.metric.id == selectedMetricID
        )
    }

    private var activeFilterValues: [BenchmarkSelectedComparisonDimensionValue] {
        scenarioGroup.comparisonDimensions.compactMap { group in
            activeValue(for: group).map {
                BenchmarkSelectedComparisonDimensionValue(
                    dimension: group.dimension,
                    value: $0,
                    title: $0.title,
                    subtitle: $0.subtitle
                )
            }
        }
    }

    private func activeValue(for group: BenchmarkComparisonDimensionGroup) -> BenchmarkComparisonDimensionValue? {
        group.values.first { value in
            filters.selectedComparisonDimensionValues[group.dimension.id]?.id == value.id
        }
    }

    private func clearFilterOption(_ dimension: BenchmarkComparisonDimension) {
        filters.selectedComparisonDimensionValues.removeValue(forKey: dimension.id)
    }
}

struct BenchmarkScenarioMetricDetailPage: View {
    let row: BenchmarkComparisonRow
    let metricTitle: String

    @State private var isNumbersExpanded = true
    @State private var isHistoryExpanded = true
    @State private var isContextExpanded = false
    @State private var isNotesExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BenchmarkMetricHeroCard(
                    row: row,
                    title: metricTitle,
                    subtitle: nil,
                    showsContextSubtitle: false
                )

                BenchmarkDisclosureSection(
                    title: "History",
                    subtitle: "Baseline and current observations for this metric.",
                    isExpanded: $isHistoryExpanded
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        BenchmarkMetricComparisonChartView(row: row)
                        BenchmarkTrendChartView(row: row)
                    }
                }

                BenchmarkDisclosureSection(
                    title: "Key Numbers",
                    subtitle: "Most important summary values for this metric.",
                    isExpanded: $isNumbersExpanded
                ) {
                    BenchmarkMetricKeyNumbersRow(row: row)
                }

                BenchmarkDisclosureSection(
                    title: "Run Context",
                    subtitle: "Use context to understand which exact runs are being compared.",
                    isExpanded: $isContextExpanded
                ) {
                    BenchmarkDetailContextView(row: row)
                }

                BenchmarkDisclosureSection(
                    title: "Notes",
                    subtitle: "Confidence, missing data, and archive notes for this metric.",
                    isExpanded: $isNotesExpanded
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        BenchmarkConfidenceView(confidence: row.confidence)
                        BenchmarkNotesPanel(row: row)
                    }
                }
            }
            .padding()
        }
    }
}
