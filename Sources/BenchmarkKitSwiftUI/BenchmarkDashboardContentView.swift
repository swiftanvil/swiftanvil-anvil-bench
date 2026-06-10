import BenchmarkKit
import SwiftUI

struct BenchmarkDashboardContentView: View {
    let presentation: BenchmarkDashboardPresentation
    let loadState: BenchmarkDashboardLoadState
    let cohorts: [BenchmarkCohort]

    @Binding var filters: BenchmarkDashboardFilterState

    let retry: () -> Void
    let rowsForNavigation: [BenchmarkComparisonRow]
    let resetHistoryAction: (@Sendable () async throws -> Void)?

    var body: some View {
        ZStack {
            switch loadState {
            case .idle, .loading:
                BenchmarkDashboardLoadingView()
            case let .loaded(loadedState):
                BenchmarkDashboardLoadedContentView(
                    presentation: presentation,
                    loadedState: loadedState,
                    filters: $filters,
                    retry: retry,
                    resetHistoryAction: resetHistoryAction
                )
            case let .failed(message):
                BenchmarkDashboardErrorView(message: message, retry: retry)
            }
        }
        .navigationDestination(for: BenchmarkSuiteRoute.self) { route in
            if let group = suiteGroup(for: route.suiteID) {
                BenchmarkSuiteDetailScreen(
                    suiteGroup: group
                )
            } else {
                unavailableView
            }
        }
        .navigationDestination(for: BenchmarkScenarioRoute.self) { route in
            if let group = scenarioGroup(for: route) {
                BenchmarkScenarioDetailScreen(
                    scenarioGroup: group,
                    initialMetricID: route.metricID,
                    filters: $filters
                )
                .id(BenchmarkScenarioDetailIdentity(
                    scenarioID: group.scenario.id,
                    selectedComparisonDimensionValues: filters.selectedComparisonDimensionValues
                ))
            } else {
                unavailableView
            }
        }
        .navigationDestination(for: BenchmarkComparisonRow.ID.self) { rowID in
            if let row = row(forID: rowID) {
                BenchmarkComparisonDetailView(row: row, cohorts: cohorts)
            } else {
                missingComparisonView
            }
        }
        .navigationDestination(for: BenchmarkComparisonRoute.self) { route in
            if let row = row(forID: route.rowID) {
                BenchmarkCohortComparisonView(
                    row: row,
                    cohorts: cohorts,
                    cohortAID: $filters.comparisonCohortAID,
                    cohortBID: $filters.comparisonCohortBID
                )
            } else {
                missingComparisonView
            }
        }
        .navigationDestination(for: BenchmarkDrillRoute.self) { route in
            if
                let row = row(forID: route.rowID),
                let sample = row.history.sortedPoints.first(where: { $0.id == route.sampleID })
            {
                BenchmarkSampleDrillView(row: row, sample: sample)
            } else {
                BenchmarkDashboardUnavailableView(
                    systemImage: "questionmark.circle",
                    title: "Sample Unavailable",
                    message: "The selected sample is no longer available for the current filters.",
                    actionTitle: nil,
                    action: nil
                )
            }
        }
    }

    private var unavailableView: some View {
        BenchmarkDashboardUnavailableView(
            systemImage: "questionmark.circle",
            title: "Benchmark View Unavailable",
            message: "The selected benchmark content is no longer available for the current filters.",
            actionTitle: nil,
            action: nil
        )
    }

    private func row(forID id: BenchmarkComparisonRow.ID) -> BenchmarkComparisonRow? {
        rowsForNavigation.first { $0.id == id }
    }

    private var missingComparisonView: some View {
        BenchmarkDashboardUnavailableView(
            systemImage: "questionmark.circle",
            title: "Comparison Unavailable",
            message: "The selected comparison is no longer available for the current filters.",
            actionTitle: nil,
            action: nil
        )
    }

    private func suiteGroup(for suiteID: BenchmarkSuite.ID) -> BenchmarkSuiteGroup? {
        guard case let .loaded(loadedState) = loadState else { return nil }
        return loadedState.groups.first { $0.suite.id == suiteID }
    }

    private func scenarioGroup(for route: BenchmarkScenarioRoute) -> BenchmarkScenarioGroup? {
        suiteGroup(for: route.suite.id)?.scenarios.first { $0.scenario.id == route.scenario.id }
    }
}

struct BenchmarkDashboardLoadedContentView: View {
    let presentation: BenchmarkDashboardPresentation
    let loadedState: BenchmarkDashboardLoadedState

    @Binding var filters: BenchmarkDashboardFilterState

    let retry: () -> Void
    let resetHistoryAction: (@Sendable () async throws -> Void)?

    @State private var isResetConfirmationPresented = false
    @State private var isResettingHistory = false
    @State private var resetErrorMessage: String?

    var body: some View {
        Group {
            if loadedState.isHistoryEmpty {
                emptyHistoryView
            } else if loadedState.rows.isEmpty {
                BenchmarkDashboardUnavailableView(
                    systemImage: "line.3.horizontal.decrease.circle",
                    title: "No Matching History",
                    message: "No benchmark history matches the current filters.",
                    actionTitle: "Reset Filters",
                    action: resetFilters
                )
            } else {
                BenchmarkDashboardHomeScreen(
                    loadedState: loadedState
                )
            }
        }
        .toolbar {
            if loadedState.rows.isEmpty == false {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: BenchmarkExportFormatter.summary(for: loadedState.rows)) {
                        Label("Export Visible", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityLabel(
                        "Export \(loadedState.rows.count) visible comparison\(loadedState.rows.count == 1 ? "" : "s")"
                    )
                }
            }

            ToolbarItem {
                Menu {
                    BenchmarkDashboardToolbarContent(
                        presentation: presentation,
                        loadedState: loadedState,
                        filters: $filters,
                        retry: retry,
                        presentResetHistory: {
                            isResetConfirmationPresented = true
                        }
                    )
                } label: {
                    Label("Options", systemImage: "slider.horizontal.3")
                }
            }
        }
        .navigationDestination(for: BenchmarkDashboardReachabilityRoute.self) { route in
            BenchmarkDashboardReachabilityDestination(
                route: route,
                loadedState: loadedState,
                insightEvaluationPolicy: presentation.insightEvaluationPolicy,
                filters: $filters,
                initialArchiveFilter: presentation.initialArchiveFilter,
                retry: retry,
                presentResetHistory: {
                    isResetConfirmationPresented = true
                }
            )
        }
        .confirmationDialog(
            "Delete all benchmark history?",
            isPresented: $isResetConfirmationPresented,
            titleVisibility: .visible
        ) {
            if resetHistoryAction != nil {
                Button("Delete History", role: .destructive) {
                    Task {
                        await resetHistory()
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes all locally recorded benchmark runs and samples so new comparisons start clean.")
        }
        .alert("Could Not Delete History", isPresented: resetErrorPresented) {
            Button("OK", role: .cancel) {
                resetErrorMessage = nil
            }
        } message: {
            Text(resetErrorMessage ?? "Unknown error.")
        }
        .overlay {
            if isResettingHistory {
                ProgressView("Deleting benchmark history…")
                    .padding(18)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    @ViewBuilder
    private var emptyHistoryView: some View {
        if loadedState.hasArchivedHistory {
            BenchmarkDashboardUnavailableView(
                systemImage: "tray",
                title: emptyHistoryTitle,
                message: emptyHistoryMessage,
                actionTitle: "Show All",
                action: showAllHistory
            )
        } else {
            BenchmarkDashboardUnavailableView(
                systemImage: "tray",
                title: emptyHistoryTitle,
                message: emptyHistoryMessage,
                actionTitle: nil,
                action: nil
            )
        }
    }

    private var emptyHistoryTitle: String {
        filters.archiveSelection == .active ? "No Active History" : "No Benchmark History"
    }

    private var emptyHistoryMessage: String {
        if filters.archiveSelection == .active, loadedState.hasArchivedHistory {
            return "No active benchmark runs are available. Archived history exists for this filter set."
        }

        return "No benchmark runs are available for the current filters."
    }

    private var resetErrorPresented: Binding<Bool> {
        Binding(
            get: { resetErrorMessage != nil },
            set: { if !$0 { resetErrorMessage = nil } }
        )
    }

    private func showAllHistory() {
        filters.archiveSelection = .all
    }

    private func resetFilters() {
        filters.reset(initialArchiveFilter: presentation.initialArchiveFilter)
    }

    @MainActor
    private func resetHistory() async {
        guard let resetHistoryAction else { return }
        isResettingHistory = true
        defer { isResettingHistory = false }

        do {
            try await resetHistoryAction()
            filters.reset(initialArchiveFilter: presentation.initialArchiveFilter)
            retry()
        } catch {
            resetErrorMessage = error.localizedDescription
        }
    }
}
