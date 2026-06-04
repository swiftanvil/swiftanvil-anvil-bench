import BenchmarkKit
import SwiftUI

struct BenchmarkDashboardToolbarContent: View {
    let presentation: BenchmarkDashboardPresentation
    let loadedState: BenchmarkDashboardLoadedState

    @Binding var filters: BenchmarkDashboardFilterState

    let retry: () -> Void
    let presentResetHistory: () -> Void

    var body: some View {
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

        if filters.selectedComparisonDimensionValues.isEmpty == false || filters.selectedTagIDs.isEmpty == false {
            Section("Selection") {
                Button("Clear Filters", role: .destructive) {
                    filters.reset(initialArchiveFilter: presentation.initialArchiveFilter)
                }
            }
        }

        Section("Actions") {
            NavigationLink(value: BenchmarkDashboardReachabilityRoute.auditMatrix) {
                Label("Audit Matrix", systemImage: "checklist")
            }
            NavigationLink(value: BenchmarkDashboardReachabilityRoute.sampleIndex) {
                Label("Sample Index", systemImage: "point.3.connected.trianglepath.dotted")
            }
            NavigationLink(value: BenchmarkDashboardReachabilityRoute.exportCenter) {
                Label("Export Center", systemImage: "square.and.arrow.up")
            }
            NavigationLink(value: BenchmarkDashboardReachabilityRoute.debugControls) {
                Label("Debug Controls", systemImage: "ladybug")
            }

            Button("Reload", systemImage: "arrow.clockwise", action: retry)
            Button("Delete History", systemImage: "trash", role: .destructive, action: presentResetHistory)
        }
    }
}
