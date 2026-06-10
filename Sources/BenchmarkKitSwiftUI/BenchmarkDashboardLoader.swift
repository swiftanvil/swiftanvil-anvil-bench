import BenchmarkKit
import Foundation

struct BenchmarkDashboardLoader<HistoryDataSource: BenchmarkHistoryDataSource> {
    var catalog: BenchmarkDashboardCatalog
    var presentation: BenchmarkDashboardPresentation
    var historyDataSource: HistoryDataSource

    func load(filters: BenchmarkDashboardFilterState) async throws -> BenchmarkDashboardLoadedState {
        let referenceDate = Date()
        let selectedDateRange = filters.dateFilter.dateRange(relativeTo: referenceDate)
        let selectedSuiteIDs = selectedSuiteIDs(for: filters)
        let selectedScenarioIDs = selectedScenarioIDs(for: filters)
        let selectedMetricIDs = selectedMetricIDs(for: filters)
        let runQuery = BenchmarkRunQuery(
            suiteIDs: selectedSuiteIDs,
            scenarioIDs: selectedScenarioIDs,
            tagIDs: filters.selectedTagIDs,
            archiveFilter: filters.archiveSelection.queryFilter,
            startedAt: selectedDateRange,
            sortOrder: .descending
        )
        let archivedRunQuery = BenchmarkRunQuery(
            suiteIDs: selectedSuiteIDs,
            scenarioIDs: selectedScenarioIDs,
            tagIDs: filters.selectedTagIDs,
            archiveFilter: .archived,
            startedAt: selectedDateRange,
            sortOrder: .descending
        )
        let baselineQuery = sampleQuery(
            filters: filters,
            scope: presentation.baseline,
            selectedMetricIDs: selectedMetricIDs,
            selectedDateRange: selectedDateRange
        )
        let currentQuery = sampleQuery(
            filters: filters,
            scope: presentation.current,
            selectedMetricIDs: selectedMetricIDs,
            selectedDateRange: selectedDateRange
        )

        async let runs = historyDataSource.runs(matching: runQuery)
        async let archivedRuns = historyDataSource.runs(matching: archivedRunQuery)
        async let baselineSamples = historyDataSource.samples(matching: baselineQuery)
        async let currentSamples = historyDataSource.samples(matching: currentQuery)

        let loadedRuns = try await runs
        let loadedArchivedRuns = try await archivedRuns
        let loadedBaselineSamples = try await baselineSamples
        let loadedCurrentSamples = try await currentSamples
        let filteredRuns = applyComparisonDimensionFilters(to: loadedRuns, filters: filters)
        let filteredBaselineSamples = applyComparisonDimensionFilters(
            to: loadedBaselineSamples,
            runs: filteredRuns,
            filters: filters
        )
        let filteredCurrentSamples = applyComparisonDimensionFilters(
            to: loadedCurrentSamples,
            runs: filteredRuns,
            filters: filters
        )
        let allRows = makeRows(
            filters: filters,
            runs: filteredRuns,
            baselineSamples: filteredBaselineSamples,
            currentSamples: filteredCurrentSamples
        )
        let visibleRows = allRows
            .filter { filters.statusFilter.accepts($0.status) }
            .sorted(by: comparisonSort)
        let latestRunStartedAt = filteredRuns.map(\.startedAt).max()
        let groups = makeGroups(rows: visibleRows, archiveSelection: filters.archiveSelection)
        let overview = BenchmarkOverviewSummary(
            rows: visibleRows,
            latestRunStartedAt: latestRunStartedAt,
            archiveSelection: filters.archiveSelection
        )

        return BenchmarkDashboardLoadedState(
            rows: visibleRows,
            groups: groups,
            recentScenarios: makeRecentScenarios(from: groups),
            overview: overview,
            hasArchivedHistory: !loadedArchivedRuns.isEmpty,
            isHistoryEmpty: filteredRuns.isEmpty && filteredBaselineSamples.isEmpty && filteredCurrentSamples.isEmpty
        )
    }

    private func selectedSuiteIDs(for filters: BenchmarkDashboardFilterState) -> Set<BenchmarkSuite.ID> {
        if let selectedSuiteID = filters.selectedSuiteID {
            return [selectedSuiteID]
        }

        if
            let selectedScenarioID = filters.selectedScenarioID,
            let scenario = catalog.scenario(withID: selectedScenarioID)
        {
            return [scenario.suiteID]
        }

        return []
    }

    private func selectedScenarioIDs(for filters: BenchmarkDashboardFilterState) -> Set<BenchmarkScenario.ID> {
        guard let selectedScenarioID = filters.selectedScenarioID else {
            return []
        }

        return [selectedScenarioID]
    }

    private func selectedMetricIDs(for filters: BenchmarkDashboardFilterState) -> Set<BenchmarkMetric.ID> {
        guard let selectedMetricID = filters.selectedMetricID else {
            return []
        }

        return [selectedMetricID]
    }

    private func sampleQuery(
        filters: BenchmarkDashboardFilterState,
        scope: BenchmarkDashboardHistoryScope,
        selectedMetricIDs: Set<BenchmarkMetric.ID>,
        selectedDateRange: BenchmarkDateRange?
    ) -> BenchmarkSampleQuery {
        BenchmarkSampleQuery(
            suiteIDs: selectedSuiteIDs(for: filters),
            scenarioIDs: selectedScenarioIDs(for: filters),
            metricIDs: selectedMetricIDs,
            tagIDs: filters.selectedTagIDs.union(scope.tagIDs),
            runArchiveFilter: filters.archiveSelection.queryFilter,
            measuredAt: scope.dateRange.intersection(with: selectedDateRange),
            sortOrder: .descending
        )
    }

    private func makeRows(
        filters: BenchmarkDashboardFilterState,
        runs: [BenchmarkRun],
        baselineSamples: [BenchmarkSample],
        currentSamples: [BenchmarkSample]
    ) -> [BenchmarkComparisonRow] {
        let suites = filteredSuites(for: filters)

        return suites.flatMap { suite in
            catalog.scenarios(in: suite.id)
                .filter { scenario in filters.selectedScenarioID == nil || scenario.id == filters.selectedScenarioID }
                .flatMap { scenario in
                    orderedMetrics(for: scenario, filters: filters).compactMap { metric in
                        makeRow(
                            suite: suite,
                            scenario: scenario,
                            metric: metric,
                            runs: runs,
                            baselineSamples: baselineSamples,
                            currentSamples: currentSamples
                        )
                    }
                }
        }
    }

    private func applyComparisonDimensionFilters(
        to runs: [BenchmarkRun],
        filters: BenchmarkDashboardFilterState
    ) -> [BenchmarkRun] {
        guard filters.selectedComparisonDimensionValues.isEmpty == false else {
            return runs
        }

        return runs
            .filter { comparisonDimensionMatches(filters.selectedComparisonDimensionValues, metadata: $0.metadata) }
    }

    private func applyComparisonDimensionFilters(
        to samples: [BenchmarkSample],
        runs: [BenchmarkRun],
        filters: BenchmarkDashboardFilterState
    ) -> [BenchmarkSample] {
        guard filters.selectedComparisonDimensionValues.isEmpty == false else {
            return samples
        }

        let runsByID = Dictionary(uniqueKeysWithValues: runs.map { ($0.id, $0) })
        return samples.filter { sample in
            let runMetadata = runsByID[sample.runID]?.metadata ?? [:]
            let merged = runMetadata.merging(sample.metadata) { _, sampleValue in sampleValue }
            return comparisonDimensionMatches(filters.selectedComparisonDimensionValues, metadata: merged)
        }
    }

    private func comparisonDimensionMatches(
        _ selectedFilters: [BenchmarkComparisonDimension.ID: BenchmarkComparisonDimensionValue],
        metadata: [String: String]
    ) -> Bool {
        selectedFilters.allSatisfy { _, value in
            value.metadataMatches.allSatisfy { key, expectedValue in
                metadata[key] == expectedValue
            }
        }
    }

    private func filteredSuites(for filters: BenchmarkDashboardFilterState) -> [BenchmarkSuite] {
        if
            let selectedSuiteID = filters.selectedSuiteID,
            let suite = catalog.suite(withID: selectedSuiteID)
        {
            return [suite]
        }

        if
            let selectedScenarioID = filters.selectedScenarioID,
            let scenario = catalog.scenario(withID: selectedScenarioID),
            let suite = catalog.suite(withID: scenario.suiteID)
        {
            return [suite]
        }

        return catalog.sortedSuites
    }

    private func orderedMetrics(
        for scenario: BenchmarkScenario,
        filters: BenchmarkDashboardFilterState
    ) -> [BenchmarkMetric] {
        if
            let selectedMetricID = filters.selectedMetricID,
            let metric = catalog.metric(withID: selectedMetricID)
        {
            return [metric]
        }

        let orderedMetricIDs = scenario.presentation?.metricOrder ?? []
        guard orderedMetricIDs.isEmpty == false else {
            return catalog.sortedMetrics
        }

        let priorityByMetricID = Dictionary(uniqueKeysWithValues: orderedMetricIDs.enumerated().map { ($1, $0) })
        let metrics = catalog.sortedMetrics

        return metrics.sorted { lhs, rhs in
            let lhsPriority = priorityByMetricID[lhs.id] ?? Int.max
            let rhsPriority = priorityByMetricID[rhs.id] ?? Int.max

            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }

            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func makeRow(
        suite: BenchmarkSuite,
        scenario: BenchmarkScenario,
        metric: BenchmarkMetric,
        runs: [BenchmarkRun],
        baselineSamples: [BenchmarkSample],
        currentSamples: [BenchmarkSample]
    ) -> BenchmarkComparisonRow? {
        let rowRuns = runs.filter { $0.suiteID == suite.id && $0.scenarioID == scenario.id }
        let rowBaselineSamples = samples(
            baselineSamples,
            suiteID: suite.id,
            scenarioID: scenario.id,
            metricID: metric.id
        )
        let rowCurrentSamples = samples(
            currentSamples,
            suiteID: suite.id,
            scenarioID: scenario.id,
            metricID: metric.id
        )
        let builder = BenchmarkComparisonBuilder(metric: metric)
        let comparison = builder.makeComparison(
            baseline: rowBaselineSamples,
            current: rowCurrentSamples
        )

        guard comparison.dataState != .missingBaselineAndCurrent else {
            return nil
        }

        let rowSamples = rowBaselineSamples + rowCurrentSamples
        let trend = builder.makeTrendSummary(from: rowSamples)
        let latestRun = rowRuns.max { $0.startedAt < $1.startedAt }
        let containsArchivedHistory = rowRuns.contains { $0.archiveState == .archived }
        let runsByID = Dictionary(rowRuns.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let dimensions = catalog.comparisonDimensions(for: scenario.id)

        return BenchmarkComparisonRow(
            suite: suite,
            scenario: scenario,
            metric: metric,
            comparison: comparison,
            trend: trend,
            status: status(for: comparison),
            containsArchivedHistory: containsArchivedHistory,
            contextSummary: latestRun.map { contextSummary(from: $0, dimensions: dimensions) },
            history: historySeries(
                metric: metric,
                baselineSamples: rowBaselineSamples,
                currentSamples: rowCurrentSamples,
                runsByID: runsByID,
                dimensions: dimensions
            ),
            matrixContexts: matrixContexts(
                baselineSamples: rowBaselineSamples,
                currentSamples: rowCurrentSamples,
                runsByID: runsByID,
                dimensions: dimensions
            ),
            confidence: confidence(for: comparison, trend: trend),
            notes: notes(for: comparison, trend: trend, containsArchivedHistory: containsArchivedHistory),
            latestRunStartedAt: latestRun?.startedAt
        )
    }

    private func samples(
        _ samples: [BenchmarkSample],
        suiteID: BenchmarkSuite.ID,
        scenarioID: BenchmarkScenario.ID,
        metricID: BenchmarkMetric.ID
    ) -> [BenchmarkSample] {
        samples.filter {
            $0.suiteID == suiteID &&
                $0.scenarioID == scenarioID &&
                $0.metricID == metricID
        }
    }

    private func status(for comparison: BenchmarkComparison) -> BenchmarkComparisonStatus {
        switch comparison.dataState {
        case .missingBaseline:
            .missingBaseline
        case .missingCurrent:
            .missingCurrent
        case .missingBaselineAndCurrent:
            .missingBaselineAndCurrent
        case .complete:
            switch comparison.trend.direction {
            case .improved:
                .improved
            case .regressed:
                .regressed
            case .unchanged:
                .unchanged
            case .unavailable:
                .unavailable
            }
        }
    }

    private func contextSummary(from run: BenchmarkRun, dimensions: [BenchmarkComparisonDimension]) -> String {
        let metadataPairs = dimensions
            .filter(\.isContextVisible)
            .compactMap { dimension -> String? in
                contextSummaryEntry(for: dimension, metadata: run.metadata)
            }

        if metadataPairs.isEmpty {
            return "Run \(run.id.rawValue)"
        }

        return metadataPairs.joined(separator: " | ")
    }

    private func contextSummaryEntry(
        for dimension: BenchmarkComparisonDimension,
        metadata: [String: String]
    ) -> String? {
        let values = dimension.keys.compactMap { metadata[$0.rawValue]?.nonEmptyTrimmed }
        guard values.isEmpty == false else {
            return nil
        }

        switch dimension.kind {
        case .singleKey:
            return "\(dimension.title): \(values[0])"
        case .identity:
            return "\(dimension.title): \(values.joined(separator: " • "))"
        }
    }

    private func historySeries(
        metric: BenchmarkMetric,
        baselineSamples: [BenchmarkSample],
        currentSamples: [BenchmarkSample],
        runsByID: [BenchmarkRun.ID: BenchmarkRun],
        dimensions: [BenchmarkComparisonDimension]
    ) -> BenchmarkMetricHistorySeries {
        BenchmarkMetricHistorySeries(
            metric: metric,
            points: historyPoints(
                samples: baselineSamples,
                scope: .baseline,
                runsByID: runsByID,
                dimensions: dimensions
            ) +
                historyPoints(samples: currentSamples, scope: .current, runsByID: runsByID, dimensions: dimensions)
        )
    }

    private func historyPoints(
        samples: [BenchmarkSample],
        scope: BenchmarkComparisonScope,
        runsByID: [BenchmarkRun.ID: BenchmarkRun],
        dimensions: [BenchmarkComparisonDimension]
    ) -> [BenchmarkMetricHistoryPoint] {
        samples.map { sample in
            let run = runsByID[sample.runID]

            return BenchmarkMetricHistoryPoint(
                id: sample.id,
                scope: scope,
                value: sample.value,
                measuredAt: sample.measuredAt,
                runID: sample.runID,
                contextSummary: run.map { contextSummary(from: $0, dimensions: dimensions) }
            )
        }
    }

    private func matrixContexts(
        baselineSamples: [BenchmarkSample],
        currentSamples: [BenchmarkSample],
        runsByID: [BenchmarkRun.ID: BenchmarkRun],
        dimensions: [BenchmarkComparisonDimension]
    ) -> [BenchmarkRunMatrixContext] {
        let baselineContexts = matrixContexts(
            for: baselineSamples,
            scope: .baseline,
            runsByID: runsByID,
            dimensions: dimensions
        )
        let currentContexts = matrixContexts(
            for: currentSamples,
            scope: .current,
            runsByID: runsByID,
            dimensions: dimensions
        )

        return (baselineContexts + currentContexts).sorted { lhs, rhs in
            if lhs.startedAt != rhs.startedAt {
                return lhs.startedAt < rhs.startedAt
            }

            return lhs.scope.title < rhs.scope.title
        }
    }

    private func matrixContexts(
        for samples: [BenchmarkSample],
        scope: BenchmarkComparisonScope,
        runsByID: [BenchmarkRun.ID: BenchmarkRun],
        dimensions: [BenchmarkComparisonDimension]
    ) -> [BenchmarkRunMatrixContext] {
        let orderedRunIDs = samples
            .map(\.runID)
            .reduce(into: [BenchmarkRun.ID]()) { runIDs, runID in
                if !runIDs.contains(runID) {
                    runIDs.append(runID)
                }
            }

        return orderedRunIDs.compactMap { runID in
            guard let run = runsByID[runID] else {
                return nil
            }

            return BenchmarkRunMatrixContext(
                scope: scope,
                runID: run.id,
                startedAt: run.startedAt,
                archiveState: run.archiveState,
                metadata: run.metadata,
                summary: contextSummary(from: run, dimensions: dimensions)
            )
        }
    }

    private func confidence(
        for comparison: BenchmarkComparison,
        trend: BenchmarkTrendSummary
    ) -> BenchmarkComparisonConfidence {
        guard comparison.dataState == .complete else {
            return BenchmarkComparisonConfidence(
                level: .low,
                summary: "One side of the comparison is missing, so the delta is unavailable."
            )
        }

        let hasLowSamples = comparison.baseline.count < presentation.lowSampleThreshold ||
            comparison.current.count < presentation.lowSampleThreshold

        if hasLowSamples {
            return BenchmarkComparisonConfidence(
                level: .medium,
                summary: "The comparison is complete, but one side has fewer samples than the configured threshold."
            )
        }

        if trend.direction == .unavailable {
            return BenchmarkComparisonConfidence(
                level: .medium,
                summary: "The comparison is complete, but the metric history does not include enough ordered samples for a trend."
            )
        }

        return BenchmarkComparisonConfidence(
            level: .high,
            summary: "Baseline, current, and trend samples are available for this metric."
        )
    }

    private func notes(
        for comparison: BenchmarkComparison,
        trend: BenchmarkTrendSummary,
        containsArchivedHistory: Bool
    ) -> [String] {
        var notes: [String] = []

        switch comparison.dataState {
        case .complete:
            break
        case .missingBaseline:
            notes.append("Missing baseline")
        case .missingCurrent:
            notes.append("Missing current")
        case .missingBaselineAndCurrent:
            notes.append("Missing baseline and current")
        }

        if comparison.baseline.count > 0, comparison.baseline.count < presentation.lowSampleThreshold {
            notes.append("Low baseline samples")
        }

        if comparison.current.count > 0, comparison.current.count < presentation.lowSampleThreshold {
            notes.append("Low current samples")
        }

        if comparison.metric.direction == .neutral {
            notes.append("Neutral metric")
        }

        if comparison.delta?.percentage == nil, comparison.delta != nil {
            notes.append("No percent delta")
        }

        if trend.direction == .unavailable, trend.sampleCount < 2 {
            notes.append("Trend needs at least two samples")
        }

        if containsArchivedHistory {
            notes.append("Archived history")
        }

        return notes
    }

    private func makeGroups(
        rows: [BenchmarkComparisonRow],
        archiveSelection: BenchmarkDashboardArchiveSelection
    ) -> [BenchmarkSuiteGroup] {
        let rowsBySuite = Dictionary(grouping: rows, by: \.suite.id)

        return catalog.sortedSuites.compactMap { suite in
            guard let suiteRows = rowsBySuite[suite.id], !suiteRows.isEmpty else {
                return nil
            }

            let rowsByScenario = Dictionary(grouping: suiteRows, by: \.scenario.id)
            let scenarios = catalog.scenarios(in: suite.id).compactMap { scenario -> BenchmarkScenarioGroup? in
                guard let scenarioRows = rowsByScenario[scenario.id], !scenarioRows.isEmpty else {
                    return nil
                }

                return BenchmarkScenarioGroup(
                    scenario: scenario,
                    rows: sortScenarioRows(scenarioRows, scenario: scenario),
                    comparisonDimensions: comparisonDimensionGroups(rows: scenarioRows, scenario: scenario),
                    summary: BenchmarkOverviewSummary(
                        rows: scenarioRows,
                        latestRunStartedAt: scenarioRows.compactMap(\.latestRunStartedAt).max(),
                        archiveSelection: archiveSelection
                    )
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.summary.latestRunStartedAt, rhs.summary.latestRunStartedAt) {
                case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                    lhsDate > rhsDate
                default:
                    lhs.scenario.name.localizedStandardCompare(rhs.scenario.name) == .orderedAscending
                }
            }

            return BenchmarkSuiteGroup(
                suite: suite,
                scenarios: scenarios,
                summary: BenchmarkOverviewSummary(
                    rows: suiteRows,
                    latestRunStartedAt: suiteRows.compactMap(\.latestRunStartedAt).max(),
                    archiveSelection: archiveSelection
                )
            )
        }
        .sorted { lhs, rhs in
            switch (lhs.summary.latestRunStartedAt, rhs.summary.latestRunStartedAt) {
            case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                lhsDate > rhsDate
            default:
                lhs.suite.name.localizedStandardCompare(rhs.suite.name) == .orderedAscending
            }
        }
    }

    private func makeRecentScenarios(from groups: [BenchmarkSuiteGroup]) -> [BenchmarkRecentScenario] {
        groups
            .flatMap { group in
                group.scenarios.map { scenarioGroup in
                    BenchmarkRecentScenario(
                        suite: group.suite,
                        scenario: scenarioGroup.scenario,
                        rows: scenarioGroup.rows,
                        summary: scenarioGroup.summary,
                        latestRunStartedAt: scenarioGroup.summary.latestRunStartedAt
                    )
                }
            }
            .sorted { lhs, rhs in
                switch (lhs.latestRunStartedAt, rhs.latestRunStartedAt) {
                case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                    lhsDate > rhsDate
                default:
                    lhs.scenario.name.localizedStandardCompare(rhs.scenario.name) == .orderedAscending
                }
            }
            .prefix(3)
            .map(\.self)
    }

    private func sortScenarioRows(
        _ rows: [BenchmarkComparisonRow],
        scenario: BenchmarkScenario
    ) -> [BenchmarkComparisonRow] {
        let priorityList = scenario.presentation?.metricOrder ?? []
        let priorityByMetricID = Dictionary(uniqueKeysWithValues: priorityList.enumerated().map { ($1, $0) })

        return rows.sorted { lhs, rhs in
            let lhsPriority = priorityByMetricID[lhs.metric.id] ?? Int.max
            let rhsPriority = priorityByMetricID[rhs.metric.id] ?? Int.max
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }

            return comparisonSort(lhs, rhs)
        }
    }

    private func comparisonDimensionGroups(
        rows: [BenchmarkComparisonRow],
        scenario: BenchmarkScenario
    ) -> [BenchmarkComparisonDimensionGroup] {
        let dimensions = catalog.comparisonDimensions(for: scenario.id)
        let contexts = rows.flatMap(\.matrixContexts)

        return dimensions.compactMap { dimension in
            guard dimension.isFilterable else {
                return nil
            }

            let values = comparisonDimensionValues(for: dimension, contexts: contexts)
            guard values.isEmpty == false else {
                return nil
            }

            return BenchmarkComparisonDimensionGroup(dimension: dimension, values: values)
        }
    }

    private func comparisonDimensionValues(
        for dimension: BenchmarkComparisonDimension,
        contexts: [BenchmarkRunMatrixContext]
    ) -> [BenchmarkComparisonDimensionValue] {
        let groupedValues = contexts.reduce(into: [String: [String: String]]()) { partialResult, context in
            let metadata = context.metadata
            let matches = dimension.keys.reduce(into: [String: String]()) { partialResult, key in
                if let value = metadata[key.rawValue]?.nonEmptyTrimmed {
                    partialResult[key.rawValue] = value
                }
            }

            guard matches.count == dimension.keys.count else {
                return
            }

            let signature = comparisonDimensionSignature(for: matches)
            if partialResult[signature] == nil {
                partialResult[signature] = matches
            }
        }

        guard groupedValues.isEmpty == false else {
            return []
        }

        let orderedValues = groupedValues.values.sorted { lhs, rhs in
            comparisonDimensionSignature(for: lhs)
                .localizedStandardCompare(comparisonDimensionSignature(for: rhs)) == .orderedAscending
        }

        return orderedValues.enumerated().map { index, metadata in
            BenchmarkComparisonDimensionValue(
                id: BenchmarkComparisonDimensionValue.ID(
                    "\(dimension.id.rawValue)::\(comparisonDimensionSignature(for: metadata))"
                ),
                title: comparisonDimensionValueTitle(for: dimension, metadata: metadata, index: index),
                subtitle: comparisonDimensionValueSubtitle(for: dimension, metadata: metadata),
                metadataMatches: metadata
            )
        }
    }

    private func comparisonDimensionSignature(for metadata: [String: String]) -> String {
        metadata.keys.sorted().compactMap { key in
            metadata[key].map { "\(key)=\($0)" }
        }
        .joined(separator: "|")
    }

    private func comparisonDimensionValueTitle(
        for dimension: BenchmarkComparisonDimension,
        metadata: [String: String],
        index: Int
    ) -> String {
        switch dimension.kind {
        case .singleKey:
            metadata[dimension.keys.first?.rawValue ?? ""] ?? dimension.title
        case .identity:
            "\(dimension.title) \(String(format: "%03d", index + 1))"
        }
    }

    private func comparisonDimensionValueSubtitle(
        for dimension: BenchmarkComparisonDimension,
        metadata: [String: String]
    ) -> String? {
        switch dimension.kind {
        case .singleKey:
            return nil
        case .identity:
            let parts = dimension.keys.compactMap { key in
                metadata[key.rawValue].map { "\(key.rawValue): \($0)" }
            }

            return parts.isEmpty ? nil : parts.joined(separator: " | ")
        }
    }

    private func comparisonSort(_ lhs: BenchmarkComparisonRow, _ rhs: BenchmarkComparisonRow) -> Bool {
        if lhs.status.sortRank != rhs.status.sortRank {
            return lhs.status.sortRank < rhs.status.sortRank
        }

        let lhsMagnitude = abs(lhs.comparison.delta?.percentage ?? lhs.comparison.delta?.absolute ?? 0)
        let rhsMagnitude = abs(rhs.comparison.delta?.percentage ?? rhs.comparison.delta?.absolute ?? 0)

        if lhsMagnitude != rhsMagnitude {
            return lhsMagnitude > rhsMagnitude
        }

        if lhs.suite.name != rhs.suite.name {
            return lhs.suite.name.localizedStandardCompare(rhs.suite.name) == .orderedAscending
        }

        if lhs.scenario.name != rhs.scenario.name {
            return lhs.scenario.name.localizedStandardCompare(rhs.scenario.name) == .orderedAscending
        }

        return lhs.metric.name.localizedStandardCompare(rhs.metric.name) == .orderedAscending
    }
}

private extension BenchmarkDateRange? {
    func intersection(with other: BenchmarkDateRange?) -> BenchmarkDateRange? {
        switch (self, other) {
        case (nil, nil):
            nil
        case let (range?, nil), let (nil, range?):
            range
        case let (lhs?, rhs?):
            BenchmarkDateRange(
                from: maxDate(lhs.lowerBound, rhs.lowerBound),
                through: minDate(lhs.upperBound, rhs.upperBound)
            )
        }
    }

    private func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            max(lhs, rhs)
        case let (lhs?, nil):
            lhs
        case let (nil, rhs?):
            rhs
        case (nil, nil):
            nil
        }
    }

    private func minDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            min(lhs, rhs)
        case let (lhs?, nil):
            lhs
        case let (nil, rhs?):
            rhs
        case (nil, nil):
            nil
        }
    }
}

private extension String {
    var nonEmptyTrimmed: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
