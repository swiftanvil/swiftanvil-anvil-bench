import BenchmarkKit
import SwiftUI

struct BenchmarkDashboardFilterBar: View {
    let catalog: BenchmarkDashboardCatalog

    @Binding var filters: BenchmarkDashboardFilterState
    @State private var isAdvancedFiltersPresented = false
    @State private var comparisonMode = BenchmarkDashboardComparisonMode.defaultMode

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                comparisonModeMenu

                ForEach(BenchmarkDashboardFilterPreset.allCases) { preset in
                    Button(action: { apply(preset) }) {
                        BenchmarkDashboardFilterPresetLabel(
                            preset: preset,
                            isSelected: preset.matches(filters)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button(action: presentAdvancedFilters) {
                    Label(advancedFiltersTitle, systemImage: "line.3.horizontal.decrease.circle")
                }
                .buttonStyle(.bordered)

                Button("Reset", systemImage: "arrow.counterclockwise", action: resetFilters)
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $isAdvancedFiltersPresented) {
            NavigationStack {
                BenchmarkDashboardAdvancedFilterSheet(
                    catalog: catalog,
                    filters: $filters,
                    comparisonMode: $comparisonMode
                )
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var comparisonModeMenu: some View {
        Menu {
            ForEach(BenchmarkDashboardComparisonMode.allCases) { mode in
                Button(action: { selectComparisonMode(mode) }) {
                    Label(mode.menuTitle, systemImage: mode.systemImage)
                }
            }
        } label: {
            BenchmarkComparisonModeLabel(mode: comparisonMode, isSelected: true)
        }
        .accessibilityLabel("Comparison mode: \(comparisonMode.menuTitle)")
        .accessibilityHint(
            "Only runs with matching comparable scenario shape, build, and device identity are eligible."
        )
    }

    private var advancedFiltersTitle: String {
        let count = advancedFilterCount

        return count == 0 ? "Advanced" : "Advanced (\(count))"
    }

    private var advancedFilterCount: Int {
        var count = 0

        if filters.selectedSuiteID != nil { count += 1 }
        if filters.selectedScenarioID != nil { count += 1 }
        if filters.selectedMetricID != nil { count += 1 }
        count += filters.selectedTagIDs.count
        count += filters.selectedComparisonDimensionValues.count

        return count
    }

    private func apply(_ preset: BenchmarkDashboardFilterPreset) {
        preset.apply(to: &filters)
    }

    private func presentAdvancedFilters() {
        isAdvancedFiltersPresented = true
    }

    private func selectComparisonMode(_ mode: BenchmarkDashboardComparisonMode) {
        comparisonMode = mode
    }

    private func resetFilters() {
        filters.reset(initialArchiveFilter: .active)
        comparisonMode = .defaultMode
    }
}
