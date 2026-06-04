import BenchmarkKit
import Foundation
import Testing
@testable import BenchmarkKitSwiftUI

@Suite("BenchmarkKitSwiftUI dashboard shell")
struct BenchmarkKitSwiftUITests {
    @Test("Demo data includes representative dashboard states")
    func demoDataIncludesRepresentativeStates() async throws {
        let activeState = try await loader(
            dataSource: BenchmarkDashboardDemoData.populatedDataSource
        )
        .load(filters: BenchmarkDashboardFilterState(archiveSelection: .active))

        #expect(activeState.rows.contains { $0.status == .improved })
        #expect(activeState.rows.contains { $0.status == .regressed })
        #expect(activeState.rows.contains { $0.status == .unchanged })
        #expect(activeState.rows.contains { $0.status == .missingCurrent })
        #expect(activeState.rows.contains { $0.status == .missingBaseline })
        #expect(activeState.rows.contains { $0.containsArchivedHistory } == false)
        #expect(activeState.overview.totalComparisons == activeState.rows.count)

        let allState = try await loader(
            dataSource: BenchmarkDashboardDemoData.populatedDataSource
        )
        .load(filters: BenchmarkDashboardFilterState(archiveSelection: .all))

        #expect(allState.rows.contains { $0.containsArchivedHistory })
        #expect(allState.hasArchivedHistory)
    }

    @Test("Loaded rows expose chart-ready history and matrix contexts")
    func loadedRowsExposeChartReadyHistoryAndMatrixContexts() async throws {
        let state = try await loader(
            dataSource: BenchmarkDashboardDemoData.populatedDataSource
        )
        .load(filters: BenchmarkDashboardFilterState(archiveSelection: .active))

        let latency = try #require(state.rows.first {
            $0.metric.name == "Latency" && $0.scenario.name == "Launch"
        })

        #expect(latency.history.sortedPoints.count >= 4)
        #expect(latency.history.sortedPoints.contains { $0.scope == .baseline })
        #expect(latency.history.sortedPoints.contains { $0.scope == .current })
        #expect(latency.matrixContexts.count >= 4)
        #expect(latency.matrixContexts.contains { $0.metadata["device"] == "Phone 16" })
        #expect(latency.confidence.level == .high)
        #expect(BenchmarkExportFormatter.summary(for: latency).contains("Matrix context"))
    }

    @Test("Demo data includes build-time improvement examples")
    func demoDataIncludesBuildTimeImprovementExamples() async throws {
        let state = try await loader(
            dataSource: BenchmarkDashboardDemoData.populatedDataSource
        )
        .load(filters: BenchmarkDashboardFilterState(archiveSelection: .active))

        let buildTime = try #require(state.rows.first { $0.metric.name == "Build Time" })

        #expect(buildTime.status == .improved)
        #expect(buildTime.metric.direction == .lowerIsBetter)
        #expect(buildTime.comparison.baseline.count == 2)
        #expect(buildTime.comparison.current.count == 2)
        #expect(buildTime.history.sortedPoints.count == 4)
    }

    @Test("Demo data includes multi-build trend stories")
    func demoDataIncludesMultiBuildTrendStories() async throws {
        let activeState = try await loader(
            dataSource: BenchmarkDashboardDemoData.populatedDataSource
        )
        .load(filters: BenchmarkDashboardFilterState(archiveSelection: .active))

        #expect(activeState.rows.contains { $0.status == .improved })
        #expect(activeState.rows.contains { $0.status == .regressed })
        #expect(activeState.rows.contains { $0.status == .unchanged })
        #expect(activeState.rows.contains { $0.status == .missingBaseline })

        let allState = try await loader(
            dataSource: BenchmarkDashboardDemoData.populatedDataSource
        )
        .load(filters: BenchmarkDashboardFilterState(archiveSelection: .all))

        let volatile = try #require(allState.rows.first { $0.scenario.name == "Volatile Build Trend" })
        let recovered = try #require(allState.rows.first { $0.scenario.name == "Recovered Build Trend" })

        #expect(volatile.history.sortedPoints.map(\.value) == [100, 130, 92, 125])
        #expect(volatile.matrixContexts.allSatisfy { $0.metadata["trendStory"] == "volatile" })
        #expect(recovered.history.sortedPoints.map(\.value) == [100, 135, 92])
        #expect(recovered.matrixContexts.allSatisfy { $0.metadata["trendStory"] == "recovered" })
    }

    @Test("Default dashboard state surfaces dense comparison-first sections")
    func defaultDashboardStateSurfacesDenseComparisonFirstSections() async throws {
        let state = try await loader(
            dataSource: BenchmarkDashboardDemoData.populatedDataSource
        )
        .load(filters: BenchmarkDashboardFilterState(archiveSelection: .active))
        let defaultState = state.defaultState

        #expect(defaultState.mode == .summary)
        #expect(defaultState.topRegressions.count == BenchmarkDashboardDefaultState.topComparisonLimit)
        #expect(defaultState.topRegressions.first?.suite.name == "Export Blocking")
        #expect(defaultState.topRegressions.map(\.status).allSatisfy { $0 == .regressed })
        #expect(defaultState.topRegressions.count < state.rows.count)
        #expect(defaultState.topRegressions.allSatisfy { $0.comparison.dataState == .complete })
        #expect(defaultState.topRegressions.allSatisfy { $0.matrixContexts.isEmpty == false })
        #expect(defaultState.topImprovements.map(\.metric.name).contains("Latency"))
        #expect(defaultState.topImprovements.map(\.metric.name).contains("Build Time"))
        #expect(defaultState.currentBaseline?.comparison.dataState == .complete)
        #expect(defaultState.primaryTrend?.metric.name == "Perceived Blocking Duration")
        #expect(state.recentScenarios.first?.scenario.name == "Collage Export")
    }

    @Test("Demo fixture keeps landing dense and comparison first")
    func demoFixtureKeepsLandingDenseAndComparisonFirst() async throws {
        let state = try await loader(
            dataSource: BenchmarkDashboardDemoData.populatedDataSource
        )
        .load(filters: BenchmarkDashboardFilterState(archiveSelection: .active))
        let defaultState = state.defaultState
        let statusCounts = Dictionary(grouping: state.rows, by: \.status).mapValues(\.count)

        #expect(state.rows.count >= 8)
        #expect(statusCounts[.regressed, default: 0] >= BenchmarkDashboardDefaultState.topComparisonLimit)
        #expect(statusCounts[.improved, default: 0] >= 2)
        #expect(statusCounts[.missingBaseline, default: 0] >= 1)
        #expect(statusCounts[.missingCurrent, default: 0] >= 1)
        #expect(statusCounts[.unchanged, default: 0] >= 1)
        if let primaryTrendID = defaultState.primaryTrend?.id {
            #expect(defaultState.topRegressions.map(\.id).contains(primaryTrendID))
        } else {
            Issue.record("Expected the dense demo fixture to provide a primary trend.")
        }
        if let currentBaselineID = defaultState.currentBaseline?.id {
            #expect(defaultState.topRegressions.map(\.id).contains(currentBaselineID))
        } else {
            Issue.record("Expected the dense demo fixture to provide a current baseline.")
        }
        #expect(state.rows.filter { $0.matrixContexts.isEmpty == false }.count > defaultState.topRegressions.count)
    }

    @Test("Default comparison insight is available before audit drilldown")
    func defaultComparisonInsightIsAvailableBeforeAuditDrilldown() async throws {
        let state = try await loader(
            dataSource: BenchmarkDashboardDemoData.populatedDataSource
        )
        .load(filters: BenchmarkDashboardFilterState(archiveSelection: .active))
        let insight = try #require(BenchmarkInsightEvaluator().visibleInsight(for: state.rows.map(\.comparison)))

        #expect(insight.kind == .regression)
        #expect(insight.comparison.metric.name == "Perceived Blocking Duration")
        #expect(insight.title.contains("Perceived Blocking Duration"))
        #expect(insight.summary.contains("Review the benchmark details before drawing conclusions."))
    }

    @Test("Landing source keeps audit and raw matrix affordances out of the first screen")
    func landingSourceKeepsAuditAndRawMatrixAffordancesOutOfFirstScreen() throws {
        let homeSource = try sourceFile(
            "Sources/BenchmarkKitSwiftUI/DashboardFlow/BenchmarkDashboardHomeScreen.swift"
        )
        let filterBarSource = try sourceFile(
            "Sources/BenchmarkKitSwiftUI/BenchmarkDashboardFilterBar.swift"
        )

        #expect(homeSource.contains("@State private var selectedMode = BenchmarkDashboardMode.defaultMode"))
        #expect(homeSource.contains("@State private var isSuitesExpanded = false"))
        #expect(homeSource.contains("@State private var isRecentExpanded = false"))
        #expect(homeSource.contains("BenchmarkDashboardReachabilityRoute") == false)
        #expect(homeSource.contains("Audit Matrix") == false)
        #expect(homeSource.contains("Debug Controls") == false)
        #expect(homeSource.contains("Run Matrix") == false)
        #expect(homeSource.contains("matrixContexts") == false)

        #expect(filterBarSource.contains("@State private var isAdvancedFiltersPresented = false"))
        #expect(filterBarSource.contains(".sheet(isPresented: $isAdvancedFiltersPresented)"))
        #expect(filterBarSource.contains("BenchmarkDashboardAdvancedFilterSheet("))
    }

    @Test("Advanced filters expose release candidate audit slices")
    func advancedFiltersExposeReleaseCandidateAuditSlices() async throws {
        var filters = BenchmarkDashboardFilterState(archiveSelection: .active)
        let profileDimensionID = BenchmarkComparisonDimension.ID("dimension.profile")
        filters.selectedComparisonDimensionValues = [
            profileDimensionID: BenchmarkComparisonDimensionValue(
                id: "dimension.profile::audit",
                title: "audit",
                metadataMatches: ["profile": "audit"]
            )
        ]

        let state = try await loader(
            dataSource: BenchmarkDashboardDemoData.populatedDataSource
        )
        .load(filters: filters)
        let exportRow = try #require(state.rows.first { $0.metric.name == "Perceived Blocking Duration" })

        #expect(state.rows.isEmpty == false)
        #expect(state.rows.allSatisfy { row in
            row.matrixContexts.allSatisfy { $0.metadata["profile"] == "audit" }
        })
        #expect(exportRow.status == .missingBaseline)
        #expect(exportRow.matrixContexts.map { $0.metadata["configuration"] }.contains("release candidate"))
        #expect(state.groups
            .flatMap(\.scenarios)
            .flatMap(\.comparisonDimensions)
            .contains { group in
                group.dimension.id.rawValue == "dimension.profile" &&
                    group.values.contains { $0.title == "audit" }
            })
    }

    @Test("Audit reachability fixtures include export shape and environment context")
    func auditReachabilityFixturesIncludeExportShapeAndEnvironmentContext() async throws {
        let state = try await loader(
            dataSource: BenchmarkDashboardDemoData.populatedDataSource
        )
        .load(filters: BenchmarkDashboardFilterState(archiveSelection: .active))
        let exportBlocking = try #require(state.rows.first {
            $0.metric.name == "Perceived Blocking Duration"
        })
        let currentContext = try #require(exportBlocking.matrixContexts.first { $0.scope == .current })
        let export = BenchmarkExportFormatter.summary(for: exportBlocking)

        #expect(exportBlocking.status == .regressed)
        #expect(exportBlocking.history.sortedPoints.count == 4)
        #expect(currentContext.metadata[BenchmarkExportShapeContext.metadataKey] != nil)
        #expect(currentContext.metadata[BenchmarkEnvironmentMetadataKey.deviceModel] == "iPhone17,1")
        #expect(currentContext.metadata[BenchmarkEnvironmentMetadataKey.gitSHA] == "demo-audit")
        #expect(export.contains("Export blocking context:"))
        #expect(export.contains("Current: Collage via imgly | Sampling: deep"))
        #expect(export.contains("Environment: iPhone17,1, arm64e"))
    }

    @Test("Missing data rows keep fallback chart and export context")
    func missingDataRowsKeepFallbackChartAndExportContext() async throws {
        let state = try await loader(
            dataSource: BenchmarkDashboardDemoData.populatedDataSource
        )
        .load(filters: BenchmarkDashboardFilterState(archiveSelection: .active))

        let missingCurrent = try #require(state.rows.first { $0.status == .missingCurrent })
        let export = BenchmarkExportFormatter.summary(for: missingCurrent)

        #expect(missingCurrent.comparison.delta == nil)
        #expect(missingCurrent.confidence.level == .low)
        #expect(missingCurrent.history.sortedPoints.isEmpty == false)
        #expect(export.contains("Missing Current"))
        #expect(export.contains("Confidence: Low Confidence"))
    }

    @Test("Archive rows preserve archived matrix and export context")
    func archiveRowsPreserveArchivedMatrixAndExportContext() async throws {
        let state = try await loader(
            dataSource: BenchmarkDashboardDemoData.populatedDataSource
        )
        .load(filters: BenchmarkDashboardFilterState(archiveSelection: .all))

        let archived = try #require(state.rows.first { $0.containsArchivedHistory })
        let export = BenchmarkExportFormatter.summary(for: archived)

        #expect(archived.matrixContexts.isEmpty == false)
        #expect(archived.matrixContexts.allSatisfy { $0.archiveState == .archived })
        #expect(archived.notes.contains("Archived history"))
        #expect(export.contains("Archived history"))
    }

    @Test("Export formatter handles empty and visible comparison states")
    func exportFormatterHandlesEmptyAndVisibleComparisonStates() async throws {
        let emptyExport = BenchmarkExportFormatter.summary(for: [])

        #expect(emptyExport.contains("No benchmark comparisons"))

        let state = try await loader(
            dataSource: BenchmarkDashboardDemoData.populatedDataSource
        )
        .load(filters: BenchmarkDashboardFilterState(archiveSelection: .active))
        let visibleExport = BenchmarkExportFormatter.summary(for: state.rows)

        #expect(visibleExport.contains("Benchmark comparison export"))
        #expect(visibleExport.contains("Build Time"))
        #expect(visibleExport.contains("Missing data"))
    }

    @Test("Export formatter includes export-blocking shape and environment history context")
    func exportFormatterIncludesExportBlockingShapeAndEnvironmentHistoryContext() throws {
        let row = try makeExportBlockingRow(includeShape: true)
        let export = BenchmarkExportFormatter.summary(for: row)
        let comparisonExport = BenchmarkExportFormatter.summary(for: [row])

        #expect(export.contains("Export blocking context:"))
        #expect(export.contains("Baseline: Collage via native | Sampling: light"))
        #expect(export.contains("Current: Collage via native | Sampling: deep"))
        #expect(export.contains("Scene: 3 pages, 12 items, 2 videos, 6 images, 3 stickers, 1 text, audio"))
        #expect(export.contains("Output: 1080x1920 px, 12.50 s, 30.00 fps, mp4, 8000 kbps"))
        #expect(export.contains("Environment: iPhone17,1, arm64e"))
        #expect(export.contains("iOS 26.0 (23A344)"))
        #expect(export.contains("26.5.3 (3212)"))
        #expect(export.contains("git abc1234"))
        #expect(export.contains("locale en_US"))
        #expect(export.contains("tz America/Los_Angeles"))
        #expect(comparisonExport.contains("Export: Collage via native | Sampling: deep"))
        #expect(comparisonExport.contains("Output: 1080x1920 px, mp4"))
    }

    @Test("Export formatter includes lifted environment context without export-shape metadata")
    func exportFormatterIncludesLiftedEnvironmentContextWithoutExportShapeMetadata() throws {
        let row = try makeExportBlockingRow(includeShape: false)
        let export = BenchmarkExportFormatter.summary(for: row)

        #expect(export.contains("Export blocking context:"))
        #expect(export.contains("Environment: iPhone17,1, arm64e"))
        #expect(export.contains("iOS 26.0 (23A344)"))
        #expect(export.contains("26.5.3 (3212)"))
        #expect(export.contains("locale en_US"))
        #expect(export.contains("tz America/Los_Angeles"))
        #expect(export.contains("Sampling: deep") == false)
        #expect(export.contains("Scene:") == false)
    }

    @Test("State filters are independent from archive filters")
    func stateFiltersAreIndependentFromArchiveFilters() async throws {
        var filters = BenchmarkDashboardFilterState(archiveSelection: .all)
        filters.statusFilter = .missingData

        let state = try await loader(
            dataSource: BenchmarkDashboardDemoData.populatedDataSource
        )
        .load(filters: filters)

        #expect(state.rows.isEmpty == false)
        #expect(state.rows.allSatisfy { $0.status.isMissingData })
        #expect(state.hasArchivedHistory)
    }

    @Test("Metadata filters narrow rows and expose filter options")
    func metadataFiltersNarrowRowsAndExposeFilterOptions() async throws {
        var filters = BenchmarkDashboardFilterState(archiveSelection: .active)
        let deviceDimensionID = BenchmarkComparisonDimension.ID("dimension.device")
        filters.selectedComparisonDimensionValues = [
            deviceDimensionID: BenchmarkComparisonDimensionValue(
                id: "dimension.device::Phone 16",
                title: "Phone 16",
                metadataMatches: ["device": "Phone 16"]
            )
        ]

        let state = try await BenchmarkDashboardLoader(
            catalog: BenchmarkDashboardDemoData.catalog,
            presentation: .init(
                baseline: BenchmarkDashboardDemoData.presentation.baseline,
                current: BenchmarkDashboardDemoData.presentation.current,
                initialArchiveFilter: BenchmarkDashboardDemoData.presentation.initialArchiveFilter,
                comparisonDimensions: BenchmarkDashboardDemoData.presentation.comparisonDimensions,
                lowSampleThreshold: BenchmarkDashboardDemoData.presentation.lowSampleThreshold
            ),
            historyDataSource: BenchmarkDashboardDemoData.populatedDataSource
        )
        .load(filters: filters)

        #expect(state.rows.isEmpty == false)
        #expect(state.rows.allSatisfy { row in
            row.matrixContexts.allSatisfy { $0.metadata["device"] == "Phone 16" }
        })
        #expect(state.groups
            .flatMap(\.scenarios)
            .flatMap(\.comparisonDimensions)
            .contains { group in
                group.dimension.id.rawValue == "dimension.device" &&
                    group.values.contains { $0.title == "Phone 16" }
            })
    }

    @Test("Visible rows sort regressions, missing data, improvements, then unchanged")
    func visibleRowsSortRegressionsMissingImprovementsUnchanged() async throws {
        let state = try await loader(
            dataSource: BenchmarkDashboardDemoData.populatedDataSource
        )
        .load(filters: BenchmarkDashboardFilterState(archiveSelection: .active))

        let ranks = state.rows.map(\.status.sortRank)
        let sortedRanks = ranks.sorted()

        #expect(ranks == sortedRanks)

        if let firstRegressedIndex = state.rows.firstIndex(where: { $0.status == .regressed }),
           let firstMissingIndex = state.rows.firstIndex(where: { $0.status.isMissingData }) {
            #expect(firstRegressedIndex < firstMissingIndex)
        }

        if let firstImprovedIndex = state.rows.firstIndex(where: { $0.status == .improved }),
           let firstUnchangedIndex = state.rows.firstIndex(where: { $0.status == .unchanged }) {
            #expect(firstImprovedIndex < firstUnchangedIndex)
        }
    }

    @Test("Visible export preserves filtered and sorted comparison set")
    func visibleExportPreservesFilteredAndSortedComparisonSet() async throws {
        var filters = BenchmarkDashboardFilterState(archiveSelection: .active)
        filters.statusFilter = .regressed

        let state = try await loader(
            dataSource: BenchmarkDashboardDemoData.populatedDataSource
        )
        .load(filters: filters)
        let export = BenchmarkExportFormatter.summary(for: state.rows)

        #expect(state.rows.isEmpty == false)
        #expect(state.rows.allSatisfy { $0.status == .regressed })
        #expect(export.contains("Comparisons: \(state.rows.count)"))

        let metricSegments = state.rows.map { "\($0.suite.name) / \($0.scenario.name) / \($0.metric.name)" }
        var lastIndex = export.startIndex
        for segment in metricSegments {
            let range = try #require(export.range(of: segment, range: lastIndex ..< export.endIndex))
            lastIndex = range.upperBound
        }

        let missingExport = BenchmarkExportFormatter.summary(for: state.rows.filter(\.status.isMissingData))
        #expect(missingExport.contains("No benchmark comparisons"))
    }

    @Test("Empty data source produces empty history state")
    func emptyDataSourceProducesEmptyHistoryState() async throws {
        let state = try await loader(
            dataSource: BenchmarkDashboardDemoData.emptyDataSource
        )
        .load(filters: BenchmarkDashboardFilterState(archiveSelection: .active))

        #expect(state.isHistoryEmpty)
        #expect(state.rows.isEmpty)
        #expect(state.overview.totalComparisons == 0)
    }

    @Test("Error data source throws demo error")
    func errorDataSourceThrowsDemoError() async {
        do {
            _ = try await loader(
                dataSource: BenchmarkDashboardDemoData.errorDataSource
            )
            .load(filters: BenchmarkDashboardFilterState(archiveSelection: .active))
            Issue.record("Expected the demo error data source to throw.")
        } catch {
            #expect(error is BenchmarkDashboardDemoError)
        }
    }

    private func loader<DataSource: BenchmarkHistoryDataSource>(
        dataSource: DataSource
    ) -> BenchmarkDashboardLoader<DataSource> {
        BenchmarkDashboardLoader(
            catalog: BenchmarkDashboardDemoData.catalog,
            presentation: BenchmarkDashboardDemoData.presentation,
            historyDataSource: dataSource
        )
    }

    private func sourceFile(_ packageRelativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let packageRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return try String(contentsOf: packageRoot.appendingPathComponent(packageRelativePath), encoding: .utf8)
    }

    private func makeExportBlockingRow(includeShape: Bool) throws -> BenchmarkComparisonRow {
        let metric = BenchmarkExportBlocking.perceivedBlockingDurationMetric
        let baselineSummary = BenchmarkSampleSummary(
            count: 3,
            mean: 4.8,
            minimum: 4.4,
            maximum: 5.1,
            latest: 4.7
        )
        let currentSummary = BenchmarkSampleSummary(
            count: 4,
            mean: 3.2,
            minimum: 3.0,
            maximum: 3.5,
            latest: 3.1
        )
        let delta = BenchmarkDelta(baseline: 4.8, current: 3.2)
        let trend = BenchmarkTrendSummary(direction: .improved, delta: delta, sampleCount: 7)
        let comparison = BenchmarkComparison(
            metric: metric,
            baseline: baselineSummary,
            current: currentSummary,
            dataState: .complete,
            delta: delta,
            trend: trend
        )

        let baselineMetadata = try exportBlockingMetadata(
            bundleBuildNumber: "3211",
            samplingProfile: .light,
            includeShape: includeShape
        )
        let currentMetadata = try exportBlockingMetadata(
            bundleBuildNumber: "3212",
            samplingProfile: .deep,
            includeShape: includeShape
        )

        return BenchmarkComparisonRow(
            suite: BenchmarkExportBlocking.suite,
            scenario: BenchmarkExportBlocking.collageScenario,
            metric: metric,
            comparison: comparison,
            trend: trend,
            status: .improved,
            containsArchivedHistory: false,
            contextSummary: "Export kind: collage | Device: iPhone17,1",
            history: BenchmarkMetricHistorySeries(metric: metric, points: []),
            matrixContexts: [
                BenchmarkRunMatrixContext(
                    scope: .baseline,
                    runID: "run.export.baseline",
                    startedAt: Date(timeIntervalSince1970: 1_715_000_000),
                    archiveState: .active,
                    metadata: baselineMetadata,
                    summary: "Baseline collage export"
                ),
                BenchmarkRunMatrixContext(
                    scope: .current,
                    runID: "run.export.current",
                    startedAt: Date(timeIntervalSince1970: 1_715_086_400),
                    archiveState: .active,
                    metadata: currentMetadata,
                    summary: "Current collage export"
                )
            ],
            confidence: BenchmarkComparisonConfidence(
                level: .high,
                summary: "Baseline, current, and trend samples are available for this metric."
            ),
            notes: ["Sampling overhead within budget"],
            latestRunStartedAt: Date(timeIntervalSince1970: 1_715_086_400)
        )
    }

    private func exportBlockingMetadata(
        bundleBuildNumber: String,
        samplingProfile: BenchmarkSamplingProfile,
        includeShape: Bool
    ) throws -> [String: String] {
        let environment = BenchmarkEnvironment(
            deviceModel: "iPhone17,1",
            cpuClass: "arm64e",
            totalPhysicalMemoryBytes: 8_589_934_592,
            osVersion: "iOS 26.0",
            osBuildNumber: "23A344",
            bundleShortVersion: "26.5.3",
            bundleBuildNumber: bundleBuildNumber,
            gitSHA: "abc1234",
            scheme: "Release",
            isSimulator: false,
            localeIdentifier: "en_US",
            timeZoneIdentifier: "America/Los_Angeles"
        )

        var metadata = BenchmarkEnvelope(environment: environment).historyMetadata()

        if includeShape {
            let shape = BenchmarkExportShapeContext(
                exportKind: .collage,
                engineRoute: .native,
                pageCount: 3,
                sceneItemCount: 12,
                videoItemCount: 2,
                imageItemCount: 6,
                stickerItemCount: 3,
                textItemCount: 1,
                hasAudio: true,
                outputWidth: 1080,
                outputHeight: 1920,
                outputDurationSeconds: 12.5,
                outputFrameRate: 30,
                outputContainer: .mp4,
                outputBitrateKbps: 8_000,
                samplingProfile: samplingProfile
            )
            metadata[BenchmarkExportShapeContext.metadataKey] = try shape.encodedString()
        }

        return metadata
    }
}
