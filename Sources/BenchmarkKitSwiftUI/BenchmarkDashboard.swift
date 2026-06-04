import BenchmarkKit
import SwiftUI

/// A generic SwiftUI dashboard for BenchmarkKit history.
public struct BenchmarkDashboard<HistoryDataSource: BenchmarkHistoryDataSource>: View {
    private let catalog: BenchmarkDashboardCatalog
    private let presentation: BenchmarkDashboardPresentation
    private let historyDataSource: HistoryDataSource
    private let resetHistoryAction: (@Sendable () async throws -> Void)?

    @State private var filters: BenchmarkDashboardFilterState
    @State private var loadState: BenchmarkDashboardLoadState = .idle
    @State private var reloadToken = UUID()
    @Environment(\.dismiss) private var dismiss

    /// Creates a benchmark dashboard.
    public init(
        catalog: BenchmarkDashboardCatalog,
        presentation: BenchmarkDashboardPresentation = BenchmarkDashboardPresentation(),
        historyDataSource: HistoryDataSource,
        resetHistoryAction: (@Sendable () async throws -> Void)? = nil
    ) {
        self.catalog = catalog
        self.presentation = presentation
        self.historyDataSource = historyDataSource
        self.resetHistoryAction = resetHistoryAction
        _filters = State(initialValue: BenchmarkDashboardFilterState(initialArchiveFilter: presentation.initialArchiveFilter))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BenchmarkDashboardFilterBar(catalog: catalog, filters: $filters)
                    .padding(.vertical, 8)
                    .benchmarkSurface(.filterBar)

                Divider()

                BenchmarkDashboardContentView(
                    presentation: presentation,
                    loadState: loadState,
                    cohorts: catalog.cohorts,
                    filters: $filters,
                    retry: reload,
                    rowsForNavigation: rowsForNavigation,
                    resetHistoryAction: resetHistoryAction
                )
            }
            .navigationTitle(presentation.title)
            .toolbar {
                ToolbarItem {
                    Button(action: dismiss.callAsFunction) {
                        Label("Close", systemImage: "xmark")
                    }
                }
                ToolbarItem {
                    Button("Reload", systemImage: "arrow.clockwise", action: reload)
                }
            }
            .task(id: BenchmarkDashboardLoadKey(filters: filters, reloadToken: reloadToken)) {
                await load()
            }
        }
#if os(iOS) || os(tvOS) || os(watchOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private var rowsForNavigation: [BenchmarkComparisonRow] {
        switch loadState {
        case let .loaded(loadedState):
            loadedState.rows
        case .idle, .loading, .failed:
            []
        }
    }

    private func reload() {
        reloadToken = UUID()
    }

    @MainActor
    private func load() async {
        loadState = .loading

        do {
            let loadedState = try await BenchmarkDashboardLoader(
                catalog: catalog,
                presentation: presentation,
                historyDataSource: historyDataSource
            )
            .load(filters: filters)

            loadState = .loaded(loadedState)
        } catch {
            loadState = .failed(Self.errorMessage(for: error))
        }
    }

    private static func errorMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let errorDescription = localizedError.errorDescription,
           !errorDescription.isEmpty {
            return errorDescription
        }

        return "The history data source could not load benchmark history."
    }
}
