import Foundation

/// A closed or half-open date range used by benchmark history queries.
public struct BenchmarkDateRange: Hashable, Codable, Sendable {
    /// The earliest accepted date.
    public var lowerBound: Date?

    /// The latest accepted date.
    public var upperBound: Date?

    /// Creates a benchmark date range.
    public init(from lowerBound: Date? = nil, through upperBound: Date? = nil) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    /// Returns whether the range contains a date.
    public func contains(_ date: Date) -> Bool {
        if let lowerBound, date < lowerBound {
            return false
        }

        if let upperBound, date > upperBound {
            return false
        }

        return true
    }
}

/// Sort order for benchmark history queries.
public enum BenchmarkSortOrder: String, Hashable, Codable, Sendable {
    /// Oldest values first.
    case ascending

    /// Newest values first.
    case descending
}

/// A filter that selects active, archived, or all benchmark history.
public enum BenchmarkArchiveFilter: Hashable, Codable, Sendable {
    /// Include active history only.
    case active

    /// Include archived history only.
    case archived

    /// Include active and archived history.
    case all

    /// Include an explicit set of archive states.
    case states(Set<BenchmarkArchiveState>)

    /// The archive states accepted by the filter.
    public var archiveStates: Set<BenchmarkArchiveState> {
        switch self {
        case .active:
            [.active]
        case .archived:
            [.archived]
        case .all:
            Set(BenchmarkArchiveState.allCases)
        case let .states(states):
            states
        }
    }

    /// Returns whether the filter accepts an archive state.
    public func contains(_ archiveState: BenchmarkArchiveState) -> Bool {
        archiveStates.contains(archiveState)
    }
}

/// A query for loading benchmark runs from a history data source.
public struct BenchmarkRunQuery: Hashable, Codable, Sendable {
    /// Suite identifiers to include.
    public var suiteIDs: Set<BenchmarkSuite.ID>

    /// Scenario identifiers to include.
    public var scenarioIDs: Set<BenchmarkScenario.ID>

    /// Tag identifiers that every returned run must contain.
    public var tagIDs: Set<BenchmarkTag.ID>

    /// The active or archived history accepted by the query.
    public var archiveFilter: BenchmarkArchiveFilter

    /// The accepted start date range.
    public var startedAt: BenchmarkDateRange?

    /// The maximum number of runs to return.
    public var limit: Int?

    /// The sort order for returned runs.
    public var sortOrder: BenchmarkSortOrder

    /// Creates a benchmark run query.
    public init(
        suiteIDs: Set<BenchmarkSuite.ID> = [],
        scenarioIDs: Set<BenchmarkScenario.ID> = [],
        tagIDs: Set<BenchmarkTag.ID> = [],
        archiveFilter: BenchmarkArchiveFilter = .all,
        startedAt: BenchmarkDateRange? = nil,
        limit: Int? = nil,
        sortOrder: BenchmarkSortOrder = .descending
    ) {
        self.suiteIDs = suiteIDs
        self.scenarioIDs = scenarioIDs
        self.tagIDs = tagIDs
        self.archiveFilter = archiveFilter
        self.startedAt = startedAt
        self.limit = limit
        self.sortOrder = sortOrder
    }

    /// Returns whether a run satisfies the query.
    public func matches(_ run: BenchmarkRun) -> Bool {
        guard suiteIDs.isEmpty || suiteIDs.contains(run.suiteID) else {
            return false
        }

        guard scenarioIDs.isEmpty || scenarioIDs.contains(run.scenarioID) else {
            return false
        }

        guard archiveFilter.contains(run.archiveState) else {
            return false
        }

        if let startedAt, !startedAt.contains(run.startedAt) {
            return false
        }

        let runTagIDs = Set(run.tags.map(\.id))
        return tagIDs.isEmpty || tagIDs.isSubset(of: runTagIDs)
    }
}

/// A query for loading benchmark samples from a history data source.
public struct BenchmarkSampleQuery: Hashable, Codable, Sendable {
    /// Run identifiers to include.
    public var runIDs: Set<BenchmarkRun.ID>

    /// Suite identifiers to include.
    public var suiteIDs: Set<BenchmarkSuite.ID>

    /// Scenario identifiers to include.
    public var scenarioIDs: Set<BenchmarkScenario.ID>

    /// Metric identifiers to include.
    public var metricIDs: Set<BenchmarkMetric.ID>

    /// Tag identifiers that every returned sample must contain.
    public var tagIDs: Set<BenchmarkTag.ID>

    /// The active or archived run history accepted by the query.
    public var runArchiveFilter: BenchmarkArchiveFilter

    /// The accepted measurement date range.
    public var measuredAt: BenchmarkDateRange?

    /// The maximum number of samples to return.
    public var limit: Int?

    /// The sort order for returned samples.
    public var sortOrder: BenchmarkSortOrder

    /// Creates a benchmark sample query.
    public init(
        runIDs: Set<BenchmarkRun.ID> = [],
        suiteIDs: Set<BenchmarkSuite.ID> = [],
        scenarioIDs: Set<BenchmarkScenario.ID> = [],
        metricIDs: Set<BenchmarkMetric.ID> = [],
        tagIDs: Set<BenchmarkTag.ID> = [],
        runArchiveFilter: BenchmarkArchiveFilter = .all,
        measuredAt: BenchmarkDateRange? = nil,
        limit: Int? = nil,
        sortOrder: BenchmarkSortOrder = .descending
    ) {
        self.runIDs = runIDs
        self.suiteIDs = suiteIDs
        self.scenarioIDs = scenarioIDs
        self.metricIDs = metricIDs
        self.tagIDs = tagIDs
        self.runArchiveFilter = runArchiveFilter
        self.measuredAt = measuredAt
        self.limit = limit
        self.sortOrder = sortOrder
    }

    /// Returns whether a sample satisfies the query.
    public func matches(_ sample: BenchmarkSample, run: BenchmarkRun? = nil) -> Bool {
        guard runIDs.isEmpty || runIDs.contains(sample.runID) else {
            return false
        }

        guard suiteIDs.isEmpty || suiteIDs.contains(sample.suiteID) else {
            return false
        }

        guard scenarioIDs.isEmpty || scenarioIDs.contains(sample.scenarioID) else {
            return false
        }

        guard metricIDs.isEmpty || metricIDs.contains(sample.metricID) else {
            return false
        }

        if let measuredAt, !measuredAt.contains(sample.measuredAt) {
            return false
        }

        if runArchiveFilter.archiveStates != Set(BenchmarkArchiveState.allCases) {
            guard let run, runArchiveFilter.contains(run.archiveState) else {
                return false
            }
        }

        let sampleTagIDs = Set(sample.tags.map(\.id))
        return tagIDs.isEmpty || tagIDs.isSubset(of: sampleTagIDs)
    }
}

/// Metadata keys used by related performance change note matching.
public enum BenchmarkRelatedPerformanceChangeNoteMetadataKey {
    /// A dashboard history scope name, such as `Current` or `Release`.
    public static let historyScopeName = "benchmark.historyScopeName"
}

/// A query that finds performance change notes related to one benchmark target.
public struct BenchmarkRelatedPerformanceChangeNoteQuery: Hashable, Codable, Sendable {
    /// The suite being compared.
    public var suiteID: BenchmarkSuite.ID?

    /// The scenario being compared.
    public var scenarioID: BenchmarkScenario.ID?

    /// The metric being compared.
    public var metricID: BenchmarkMetric.ID?

    /// The comparable scenario shape for the compared run.
    public var scenarioFingerprint: BenchmarkScenarioFingerprint?

    /// Areas accepted by the query. Empty means all areas are accepted.
    public var areas: Set<BenchmarkPerformanceChangeArea>

    /// Dashboard history scope accepted by the query.
    public var historyScopeName: String?

    /// The build number for the compared run.
    public var referenceBuildNumber: String

    /// Maximum numeric build distance accepted as recent.
    public var maximumBuildDistance: Int

    /// Active or archived run history to search for bundled notes.
    public var runArchiveFilter: BenchmarkArchiveFilter

    /// The maximum number of related notes to return.
    public var limit: Int?

    /// Creates a related performance change note query.
    public init(
        suiteID: BenchmarkSuite.ID? = nil,
        scenarioID: BenchmarkScenario.ID? = nil,
        metricID: BenchmarkMetric.ID? = nil,
        scenarioFingerprint: BenchmarkScenarioFingerprint? = nil,
        areas: Set<BenchmarkPerformanceChangeArea> = [],
        historyScopeName: String? = nil,
        referenceBuildNumber: String,
        maximumBuildDistance: Int = 10,
        runArchiveFilter: BenchmarkArchiveFilter = .active,
        limit: Int? = nil
    ) {
        self.suiteID = suiteID
        self.scenarioID = scenarioID
        self.metricID = metricID
        self.scenarioFingerprint = scenarioFingerprint
        self.areas = areas
        self.historyScopeName = historyScopeName?.nonEmptyBenchmarkQueryValue
        self.referenceBuildNumber = referenceBuildNumber
        self.maximumBuildDistance = max(0, maximumBuildDistance)
        self.runArchiveFilter = runArchiveFilter
        self.limit = limit
    }

    /// Creates a query for a run and metric in a dashboard history scope.
    public init(
        run: BenchmarkRun,
        metricID: BenchmarkMetric.ID? = nil,
        areas: Set<BenchmarkPerformanceChangeArea> = [],
        historyScope: BenchmarkDashboardHistoryScope? = nil,
        maximumBuildDistance: Int = 10,
        runArchiveFilter: BenchmarkArchiveFilter = .active,
        limit: Int? = nil
    ) {
        self.init(
            suiteID: run.suiteID,
            scenarioID: run.scenarioID,
            metricID: metricID,
            scenarioFingerprint: run.scenarioFingerprint,
            areas: areas,
            historyScopeName: historyScope?.name,
            referenceBuildNumber: run.envelope?.environment.bundleBuildNumber ??
                run.metadata[BenchmarkEnvironmentMetadataKey.bundleBuildNumber] ??
                "",
            maximumBuildDistance: maximumBuildDistance,
            runArchiveFilter: runArchiveFilter,
            limit: limit
        )
    }

    /// Returns the related-note match for a note, when the note belongs to this query.
    public func match(
        for note: BenchmarkPerformanceChangeNote
    ) -> BenchmarkRelatedPerformanceChangeNote? {
        guard areas.isEmpty || areas.contains(note.area) else {
            return nil
        }

        guard let buildDistance = matchingBuildDistance(for: note.buildIntroduced.bundleBuildNumber) else {
            return nil
        }

        return note.affectedBenchmarks
            .compactMap { affectedBenchmark in
                match(for: note, affectedBenchmark: affectedBenchmark, buildDistance: buildDistance)
            }
            .sorted(by: relatedPerformanceChangeNoteSort)
            .first
    }

    private func match(
        for note: BenchmarkPerformanceChangeNote,
        affectedBenchmark: BenchmarkPerformanceChangeAffectedBenchmark,
        buildDistance: Int?
    ) -> BenchmarkRelatedPerformanceChangeNote? {
        guard affectedBenchmark.referencesBenchmark else {
            return nil
        }

        var matchedScopes: Set<BenchmarkRelatedPerformanceChangeNoteScope> = []

        if let affectedSuiteID = affectedBenchmark.suiteID {
            guard affectedSuiteID == suiteID else {
                return nil
            }
            matchedScopes.insert(.suite)
        }

        if let affectedScenarioID = affectedBenchmark.scenarioID {
            guard affectedScenarioID == scenarioID else {
                return nil
            }
            matchedScopes.insert(.scenario)
        }

        if let affectedMetricID = affectedBenchmark.metricID {
            guard affectedMetricID == metricID else {
                return nil
            }
            matchedScopes.insert(.metric)
        }

        if let affectedFingerprint = affectedBenchmark.scenarioFingerprint {
            guard let fingerprintScope = matchedScope(for: affectedFingerprint) else {
                return nil
            }
            matchedScopes.insert(fingerprintScope)
        }

        guard matchesHistoryScope(note: note, affectedBenchmark: affectedBenchmark) else {
            return nil
        }

        if declaredHistoryScopeName(in: note, affectedBenchmark: affectedBenchmark) != nil {
            matchedScopes.insert(.historyScope)
        }

        guard matchedScopes.isEmpty == false else {
            return nil
        }

        return BenchmarkRelatedPerformanceChangeNote(
            note: note,
            affectedBenchmark: affectedBenchmark,
            matchedScopes: matchedScopes,
            buildDistance: buildDistance
        )
    }

    private func matchingBuildDistance(for noteBuildNumber: String) -> Int?? {
        guard let noteBuildNumber = noteBuildNumber.nonEmptyBenchmarkQueryValue,
              let referenceBuildNumber = referenceBuildNumber.nonEmptyBenchmarkQueryValue
        else {
            return nil
        }

        guard
            let noteBuild = Int(noteBuildNumber),
            let referenceBuild = Int(referenceBuildNumber)
        else {
            return noteBuildNumber == referenceBuildNumber ? .some(nil) : nil
        }

        let distance = referenceBuild - noteBuild
        guard distance >= 0 && distance <= maximumBuildDistance else {
            return nil
        }

        return .some(distance)
    }

    private func matchedScope(
        for affectedFingerprint: BenchmarkScenarioFingerprint
    ) -> BenchmarkRelatedPerformanceChangeNoteScope? {
        guard let scenarioFingerprint else {
            return nil
        }

        if scenarioFingerprint.isInSameFuzzyBucket(as: affectedFingerprint) {
            return .scenarioFingerprint
        }

        let affectedWorkflow = affectedFingerprint.strictGates.value(for: .workflow)?.nonEmptyBenchmarkQueryValue
        let referenceWorkflow = scenarioFingerprint.strictGates.value(for: .workflow)?.nonEmptyBenchmarkQueryValue
        if affectedWorkflow != nil && affectedWorkflow == referenceWorkflow {
            return .workflowFamily
        }

        return nil
    }

    private func matchesHistoryScope(
        note: BenchmarkPerformanceChangeNote,
        affectedBenchmark: BenchmarkPerformanceChangeAffectedBenchmark
    ) -> Bool {
        guard let declaredScope = declaredHistoryScopeName(in: note, affectedBenchmark: affectedBenchmark) else {
            return true
        }

        return declaredScope == historyScopeName?.nonEmptyBenchmarkQueryValue
    }

    private func declaredHistoryScopeName(
        in note: BenchmarkPerformanceChangeNote,
        affectedBenchmark: BenchmarkPerformanceChangeAffectedBenchmark
    ) -> String? {
        let affectedScope = affectedBenchmark
            .metadata[BenchmarkRelatedPerformanceChangeNoteMetadataKey.historyScopeName]?
            .nonEmptyBenchmarkQueryValue
        let noteScope = note
            .metadata[BenchmarkRelatedPerformanceChangeNoteMetadataKey.historyScopeName]?
            .nonEmptyBenchmarkQueryValue

        return affectedScope ?? noteScope
    }

    private func relatedPerformanceChangeNoteSort(
        _ lhs: BenchmarkRelatedPerformanceChangeNote,
        _ rhs: BenchmarkRelatedPerformanceChangeNote
    ) -> Bool {
        let lhsDistance = lhs.buildDistance ?? 0
        let rhsDistance = rhs.buildDistance ?? 0
        if lhsDistance != rhsDistance {
            return lhsDistance < rhsDistance
        }

        let lhsSpecificity = specificity(of: lhs.matchedScopes)
        let rhsSpecificity = specificity(of: rhs.matchedScopes)
        if lhsSpecificity != rhsSpecificity {
            return lhsSpecificity > rhsSpecificity
        }

        return lhs.note.id.rawValue < rhs.note.id.rawValue
    }

    private func specificity(of scopes: Set<BenchmarkRelatedPerformanceChangeNoteScope>) -> Int {
        scopes.reduce(0) { score, scope in
            switch scope {
            case .metric:
                score + 32
            case .scenario:
                score + 16
            case .suite:
                score + 8
            case .scenarioFingerprint:
                score + 4
            case .workflowFamily:
                score + 2
            case .historyScope:
                score + 1
            }
        }
    }
}

/// A source that can load benchmark history without exposing storage-specific types.
public protocol BenchmarkHistoryDataSource: Sendable {
    /// Loads runs that match a query.
    func runs(matching query: BenchmarkRunQuery) async throws -> [BenchmarkRun]

    /// Loads samples that match a query.
    func samples(matching query: BenchmarkSampleQuery) async throws -> [BenchmarkSample]
}

public extension BenchmarkHistoryDataSource {
    /// Loads bundled performance change notes related to a benchmark query.
    func relatedPerformanceChangeNotes(
        matching query: BenchmarkRelatedPerformanceChangeNoteQuery
    ) async throws -> [BenchmarkRelatedPerformanceChangeNote] {
        let candidateRuns = try await runs(
            matching: BenchmarkRunQuery(
                archiveFilter: query.runArchiveFilter,
                sortOrder: .descending
            )
        )

        var matchesByID: [BenchmarkPerformanceChangeNote.ID: BenchmarkRelatedPerformanceChangeNote] = [:]
        for note in candidateRuns.compactMap(\.envelope).flatMap(\.performanceChangeNotes) {
            guard let match = query.match(for: note) else {
                continue
            }

            if let existingMatch = matchesByID[note.id] {
                if relatedPerformanceChangeNoteSort(match, existingMatch) {
                    matchesByID[note.id] = match
                }
            } else {
                matchesByID[note.id] = match
            }
        }

        return matchesByID.values
            .sorted(by: relatedPerformanceChangeNoteSort)
            .limited(to: query.limit)
    }

    /// Loads the nearest older run in the same comparable trend bucket.
    ///
    /// The lookup is conservative when envelope data is available: the reference
    /// and candidate runs must share a scenario fingerprint, bundle build number,
    /// and device model. Legacy runs without envelope data fall back to fingerprint
    /// bucket matching. Runs that start at the same time as the reference run are
    /// not considered previous.
    func nearestPreviousComparableRun(
        before referenceRun: BenchmarkRun,
        archiveFilter: BenchmarkArchiveFilter = .active
    ) async throws -> BenchmarkRun? {
        if let referenceGroupKey = BenchmarkComparableRunGroupKey(run: referenceRun) {
            return try await nearestPreviousComparableRun(
                before: referenceRun,
                archiveFilter: archiveFilter
            ) { candidateRun in
                referenceGroupKey.contains(candidateRun)
            }
        }

        guard referenceRun.envelope == nil else {
            return nil
        }

        return try await nearestPreviousLegacyComparableRun(
            before: referenceRun,
            archiveFilter: archiveFilter
        )
    }

    private func nearestPreviousLegacyComparableRun(
        before referenceRun: BenchmarkRun,
        archiveFilter: BenchmarkArchiveFilter
    ) async throws -> BenchmarkRun? {
        guard let referenceFingerprint = referenceRun.scenarioFingerprint else {
            return nil
        }

        return try await nearestPreviousComparableRun(
            before: referenceRun,
            archiveFilter: archiveFilter
        ) { candidateRun in
            guard candidateRun.envelope == nil,
                  let candidateFingerprint = candidateRun.scenarioFingerprint
            else {
                return false
            }

            return candidateFingerprint.isInSameFuzzyBucket(as: referenceFingerprint)
        }
    }

    private func nearestPreviousComparableRun(
        before referenceRun: BenchmarkRun,
        archiveFilter: BenchmarkArchiveFilter,
        isComparable: @escaping (BenchmarkRun) -> Bool
    ) async throws -> BenchmarkRun? {
        let candidateRuns = try await runs(
            matching: BenchmarkRunQuery(
                suiteIDs: [referenceRun.suiteID],
                scenarioIDs: [referenceRun.scenarioID],
                archiveFilter: archiveFilter,
                startedAt: BenchmarkDateRange(through: referenceRun.startedAt),
                sortOrder: .descending
            )
        )

        return candidateRuns.first { candidateRun in
            candidateRun.id != referenceRun.id &&
                candidateRun.startedAt < referenceRun.startedAt &&
                isComparable(candidateRun)
        }
    }
}

/// An immutable in-memory history source for previews, tests, and simple adapters.
public struct BenchmarkHistorySnapshot: BenchmarkHistoryDataSource {
    /// Runs available to the snapshot.
    public var runs: [BenchmarkRun]

    /// Samples available to the snapshot.
    public var samples: [BenchmarkSample]

    /// Creates an immutable benchmark history snapshot.
    public init(runs: [BenchmarkRun] = [], samples: [BenchmarkSample] = []) {
        self.runs = runs
        self.samples = samples
    }

    /// Loads runs that match a query.
    public func runs(matching query: BenchmarkRunQuery) async throws -> [BenchmarkRun] {
        let sortedRuns = runs
            .filter(query.matches)
            .sorted { lhs, rhs in
                switch query.sortOrder {
                case .ascending:
                    lhs.startedAt < rhs.startedAt
                case .descending:
                    lhs.startedAt > rhs.startedAt
                }
            }

        return sortedRuns.limited(to: query.limit)
    }

    /// Loads samples that match a query.
    public func samples(matching query: BenchmarkSampleQuery) async throws -> [BenchmarkSample] {
        let runsByID = Dictionary(uniqueKeysWithValues: runs.map { ($0.id, $0) })
        let sortedSamples = samples
            .filter { sample in
                query.matches(sample, run: runsByID[sample.runID])
            }
            .sorted { lhs, rhs in
                switch query.sortOrder {
                case .ascending:
                    lhs.measuredAt < rhs.measuredAt
                case .descending:
                    lhs.measuredAt > rhs.measuredAt
                }
            }

        return sortedSamples.limited(to: query.limit)
    }
}

private func relatedPerformanceChangeNoteSort(
    _ lhs: BenchmarkRelatedPerformanceChangeNote,
    _ rhs: BenchmarkRelatedPerformanceChangeNote
) -> Bool {
    let lhsDistance = lhs.buildDistance ?? 0
    let rhsDistance = rhs.buildDistance ?? 0
    if lhsDistance != rhsDistance {
        return lhsDistance < rhsDistance
    }

    let lhsSpecificity = relatedPerformanceChangeNoteSpecificity(of: lhs.matchedScopes)
    let rhsSpecificity = relatedPerformanceChangeNoteSpecificity(of: rhs.matchedScopes)
    if lhsSpecificity != rhsSpecificity {
        return lhsSpecificity > rhsSpecificity
    }

    return lhs.note.id.rawValue < rhs.note.id.rawValue
}

private func relatedPerformanceChangeNoteSpecificity(
    of scopes: Set<BenchmarkRelatedPerformanceChangeNoteScope>
) -> Int {
    scopes.reduce(0) { score, scope in
        switch scope {
        case .metric:
            score + 32
        case .scenario:
            score + 16
        case .suite:
            score + 8
        case .scenarioFingerprint:
            score + 4
        case .workflowFamily:
            score + 2
        case .historyScope:
            score + 1
        }
    }
}

private extension String {
    var nonEmptyBenchmarkQueryValue: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private extension Array {
    func limited(to limit: Int?) -> Self {
        guard let limit else {
            return self
        }

        return Array(prefix(Swift.max(0, limit)))
    }
}
