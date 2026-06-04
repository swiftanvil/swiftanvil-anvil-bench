import Foundation

/// A stable key used to build comparison-dimension definitions from metadata fields.
public struct BenchmarkComparisonDimensionKey: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    /// The persisted key value.
    public let rawValue: String

    /// Creates a comparison-dimension key from a raw string value.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a comparison-dimension key from a raw string value.
    public init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    /// Creates a comparison-dimension key from a string literal.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// A human-readable representation of the key.
    public var description: String {
        rawValue
    }
}

/// Whether a comparison dimension represents a single key or an identity made of multiple keys.
public enum BenchmarkComparisonDimensionKind: String, Hashable, Codable, Sendable {
    /// A dimension that resolves from one metadata key.
    case singleKey

    /// A dimension that resolves from multiple keys that together form an identity.
    case identity
}

/// Where a comparison dimension should appear in the dashboard presentation.
public enum BenchmarkComparisonDimensionVisibility: String, Hashable, Codable, Sendable {
    /// Show the dimension in run-context summaries.
    case context

    /// Show the dimension in compare/filter controls.
    case filter

    /// Show the dimension in both run-context summaries and compare/filter controls.
    case both
}

/// A generic comparison dimension that can be surfaced in dashboard context and filtering UI.
public struct BenchmarkComparisonDimension: Identifiable, Hashable, Codable, Sendable {
    /// The comparison-dimension identifier type.
    public typealias ID = BenchmarkID<Self>

    /// The stable dimension identifier.
    public var id: ID

    /// The display name for the dimension.
    public var title: String

    /// The kind of dimension represented by the key list.
    public var kind: BenchmarkComparisonDimensionKind

    /// The visibility hint that controls where the dimension appears.
    public var visibility: BenchmarkComparisonDimensionVisibility

    /// The metadata keys used to resolve this dimension.
    public var keys: [BenchmarkComparisonDimensionKey]

    /// Creates a comparison dimension.
    public init(
        id: ID,
        title: String,
        kind: BenchmarkComparisonDimensionKind,
        visibility: BenchmarkComparisonDimensionVisibility = .both,
        keys: [BenchmarkComparisonDimensionKey]
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.visibility = visibility
        self.keys = keys
    }

    /// Whether the dimension may be used in filter UI.
    public var isFilterable: Bool {
        visibility == .filter || visibility == .both
    }

    /// Whether the dimension should appear in run-context summaries.
    public var isContextVisible: Bool {
        visibility == .context || visibility == .both
    }

    /// Returns whether a metadata dictionary contains every key required by the dimension.
    public func matchesMetadata(_ metadata: [String: String]) -> Bool {
        keys.allSatisfy { key in
            metadata[key.rawValue]?.isEmpty == false
        }
    }
}

/// A selectable value for a comparison dimension.
public struct BenchmarkComparisonDimensionValue: Identifiable, Hashable, Codable, Sendable {
    /// The comparison-dimension-value identifier type.
    public typealias ID = BenchmarkID<Self>

    /// The stable value identifier.
    public var id: ID

    /// The display name for the value.
    public var title: String

    /// An optional secondary label for the value.
    public var subtitle: String?

    /// The metadata pairs that define the value.
    public var metadataMatches: [String: String]

    /// Creates a comparison-dimension value.
    public init(
        id: ID,
        title: String,
        subtitle: String? = nil,
        metadataMatches: [String: String]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.metadataMatches = metadataMatches
    }
}

/// The kind of benchmark identifier referenced by a performance change note.
public enum BenchmarkPerformanceChangeBenchmarkIDKind: String, CaseIterable, Hashable, Codable, Sendable {
    /// A benchmark suite identifier.
    case suite

    /// A benchmark scenario identifier.
    case scenario

    /// A benchmark metric identifier.
    case metric
}

/// A benchmark identifier that is not present in a registry.
public struct BenchmarkPerformanceChangeInvalidBenchmarkID: Hashable, Codable, Sendable {
    /// The kind of benchmark identifier that failed validation.
    public var kind: BenchmarkPerformanceChangeBenchmarkIDKind

    /// The missing raw identifier value.
    public var rawValue: String

    /// Creates an invalid benchmark identifier result.
    public init(kind: BenchmarkPerformanceChangeBenchmarkIDKind, rawValue: String) {
        self.kind = kind
        self.rawValue = rawValue
    }
}

/// The result of validating a performance change note against a benchmark identifier registry.
public struct BenchmarkPerformanceChangeNoteValidation: Hashable, Codable, Sendable {
    /// Invalid benchmark identifiers referenced by the note.
    public var invalidBenchmarkIDs: [BenchmarkPerformanceChangeInvalidBenchmarkID]

    /// Whether the note explicitly declares that it has no benchmark impact.
    public var declaresNoBenchmarkImpact: Bool

    /// Whether the note references at least one benchmark identifier or scenario fingerprint.
    public var hasBenchmarkReferences: Bool

    /// Whether the note mixes an explicit no-impact declaration with benchmark references.
    public var hasConflictingBenchmarkImpactDeclaration: Bool

    /// Creates a note validation result.
    public init(
        invalidBenchmarkIDs: [BenchmarkPerformanceChangeInvalidBenchmarkID],
        declaresNoBenchmarkImpact: Bool,
        hasBenchmarkReferences: Bool,
        hasConflictingBenchmarkImpactDeclaration: Bool
    ) {
        self.invalidBenchmarkIDs = invalidBenchmarkIDs
        self.declaresNoBenchmarkImpact = declaresNoBenchmarkImpact
        self.hasBenchmarkReferences = hasBenchmarkReferences
        self.hasConflictingBenchmarkImpactDeclaration = hasConflictingBenchmarkImpactDeclaration
    }

    /// Whether the note has a valid benchmark impact declaration.
    public var isValid: Bool {
        invalidBenchmarkIDs.isEmpty &&
            hasConflictingBenchmarkImpactDeclaration == false &&
            (declaresNoBenchmarkImpact || hasBenchmarkReferences)
    }
}

/// A registry of benchmark identifiers accepted by performance change notes.
public struct BenchmarkIDRegistry: Hashable, Sendable {
    /// Suite identifiers accepted by the registry.
    public var suiteIDs: Set<BenchmarkSuite.ID>

    /// Scenario identifiers accepted by the registry.
    public var scenarioIDs: Set<BenchmarkScenario.ID>

    /// Metric identifiers accepted by the registry.
    public var metricIDs: Set<BenchmarkMetric.ID>

    /// Creates a benchmark identifier registry from identifier sets.
    public init(
        suiteIDs: Set<BenchmarkSuite.ID> = [],
        scenarioIDs: Set<BenchmarkScenario.ID> = [],
        metricIDs: Set<BenchmarkMetric.ID> = []
    ) {
        self.suiteIDs = suiteIDs
        self.scenarioIDs = scenarioIDs
        self.metricIDs = metricIDs
    }

    /// Creates a benchmark identifier registry from dashboard catalog models.
    public init(
        suites: [BenchmarkSuite],
        scenarios: [BenchmarkScenario],
        metrics: [BenchmarkMetric]
    ) {
        self.init(
            suiteIDs: Set(suites.map(\.id)),
            scenarioIDs: Set(scenarios.map(\.id)),
            metricIDs: Set(metrics.map(\.id))
        )
    }

    /// Creates a benchmark identifier registry from a dashboard catalog.
    public init(catalog: BenchmarkDashboardCatalog) {
        self.init(
            suites: catalog.suites,
            scenarios: catalog.scenarios,
            metrics: catalog.metrics
        )
    }

    /// Returns whether the registry contains a suite identifier.
    public func contains(suiteID: BenchmarkSuite.ID) -> Bool {
        suiteIDs.contains(suiteID)
    }

    /// Returns whether the registry contains a scenario identifier.
    public func contains(scenarioID: BenchmarkScenario.ID) -> Bool {
        scenarioIDs.contains(scenarioID)
    }

    /// Returns whether the registry contains a metric identifier.
    public func contains(metricID: BenchmarkMetric.ID) -> Bool {
        metricIDs.contains(metricID)
    }

    /// Returns invalid benchmark identifiers in an affected benchmark reference.
    public func invalidBenchmarkIDs(
        in affectedBenchmark: BenchmarkPerformanceChangeAffectedBenchmark
    ) -> [BenchmarkPerformanceChangeInvalidBenchmarkID] {
        var invalidIDs: [BenchmarkPerformanceChangeInvalidBenchmarkID] = []

        if let suiteID = affectedBenchmark.suiteID, contains(suiteID: suiteID) == false {
            invalidIDs.append(.init(kind: .suite, rawValue: suiteID.rawValue))
        }

        if let scenarioID = affectedBenchmark.scenarioID, contains(scenarioID: scenarioID) == false {
            invalidIDs.append(.init(kind: .scenario, rawValue: scenarioID.rawValue))
        }

        if let metricID = affectedBenchmark.metricID, contains(metricID: metricID) == false {
            invalidIDs.append(.init(kind: .metric, rawValue: metricID.rawValue))
        }

        return invalidIDs
    }

    /// Validates benchmark references and explicit no-impact declarations in a performance change note.
    public func validate(_ note: BenchmarkPerformanceChangeNote) -> BenchmarkPerformanceChangeNoteValidation {
        let invalidBenchmarkIDs = note.affectedBenchmarks.flatMap(invalidBenchmarkIDs(in:))
        let declaresNoBenchmarkImpact = note.affectedBenchmarks.contains { $0.declaresNoBenchmarkImpact }
        let hasBenchmarkReferences = note.affectedBenchmarks.contains { $0.referencesBenchmark }

        return BenchmarkPerformanceChangeNoteValidation(
            invalidBenchmarkIDs: invalidBenchmarkIDs,
            declaresNoBenchmarkImpact: declaresNoBenchmarkImpact,
            hasBenchmarkReferences: hasBenchmarkReferences,
            hasConflictingBenchmarkImpactDeclaration: declaresNoBenchmarkImpact && hasBenchmarkReferences
        )
    }
}

public extension BenchmarkPerformanceChangeAffectedBenchmark {
    /// Metadata key used when a note explicitly declares no benchmark impact.
    static let benchmarkImpactMetadataKey = "benchmarkImpact"

    /// Metadata value used when a note explicitly declares no benchmark impact.
    static let noBenchmarkImpactMetadataValue = "none"

    /// An explicit declaration that a performance change note has no benchmark impact.
    static let noBenchmarkImpact = Self(metadata: [
        benchmarkImpactMetadataKey: noBenchmarkImpactMetadataValue
    ])

    /// Whether this reference explicitly declares no benchmark impact.
    var declaresNoBenchmarkImpact: Bool {
        suiteID == nil &&
            scenarioID == nil &&
            metricID == nil &&
            scenarioFingerprint == nil &&
            metadata[Self.benchmarkImpactMetadataKey] == Self.noBenchmarkImpactMetadataValue
    }

    /// Whether this reference points at a benchmark identifier or comparable scenario fingerprint.
    var referencesBenchmark: Bool {
        suiteID != nil || scenarioID != nil || metricID != nil || scenarioFingerprint != nil
    }
}

/// Presentation hints for a benchmark scenario.
public struct BenchmarkScenarioPresentation: Hashable, Codable, Sendable {
    /// The primary metric for the scenario.
    public var primaryMetricID: BenchmarkMetric.ID?

    /// The order used to surface metrics for the scenario.
    public var metricOrder: [BenchmarkMetric.ID]

    /// The comparison dimensions relevant to this scenario.
    public var comparisonDimensionIDs: [BenchmarkComparisonDimension.ID]

    /// Creates scenario presentation hints.
    public init(
        primaryMetricID: BenchmarkMetric.ID? = nil,
        metricOrder: [BenchmarkMetric.ID] = [],
        comparisonDimensionIDs: [BenchmarkComparisonDimension.ID] = []
    ) {
        self.primaryMetricID = primaryMetricID
        self.metricOrder = metricOrder
        self.comparisonDimensionIDs = comparisonDimensionIDs
    }
}

/// A named slice of benchmark history used by the dashboard comparison loader.
public struct BenchmarkDashboardHistoryScope: Hashable, Codable, Sendable {
    /// The label displayed for the scope.
    public var name: String

    /// The measurement date range accepted by the scope.
    public var dateRange: BenchmarkDateRange?

    /// Tags that samples must include to belong to the scope.
    public var tagIDs: Set<BenchmarkTag.ID>

    /// Creates a dashboard history scope.
    public init(
        name: String,
        dateRange: BenchmarkDateRange? = nil,
        tagIDs: Set<BenchmarkTag.ID> = []
    ) {
        self.name = name
        self.dateRange = dateRange
        self.tagIDs = tagIDs
    }
}

/// The suites, scenarios, metrics, and comparison dimensions available to a benchmark dashboard.
public struct BenchmarkDashboardCatalog: Hashable, Sendable {
    /// Suites that can be shown by the dashboard.
    public var suites: [BenchmarkSuite]

    /// Scenarios that can be shown by the dashboard.
    public var scenarios: [BenchmarkScenario]

    /// Metrics that can be shown by the dashboard.
    public var metrics: [BenchmarkMetric]

    /// Comparison dimensions that can be shown by the dashboard.
    public var comparisonDimensions: [BenchmarkComparisonDimension]

    /// Saved cohorts available in the dashboard's filter bar and comparison picker.
    public var cohorts: [BenchmarkCohort]

    /// Creates a dashboard catalog from BenchmarkKit model values.
    public init(
        suites: [BenchmarkSuite],
        scenarios: [BenchmarkScenario],
        metrics: [BenchmarkMetric],
        comparisonDimensions: [BenchmarkComparisonDimension] = [],
        cohorts: [BenchmarkCohort] = []
    ) {
        self.suites = suites
        self.scenarios = scenarios
        self.metrics = metrics
        self.comparisonDimensions = comparisonDimensions
        self.cohorts = cohorts
    }

    /// Whether the catalog contains no dashboard dimensions.
    public var isEmpty: Bool {
        suites.isEmpty || scenarios.isEmpty || metrics.isEmpty
    }

    /// Returns suites ordered by display name.
    public var sortedSuites: [BenchmarkSuite] {
        suites.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Returns metrics ordered by display name.
    public var sortedMetrics: [BenchmarkMetric] {
        metrics.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Returns comparison dimensions ordered by display name.
    public var sortedComparisonDimensions: [BenchmarkComparisonDimension] {
        comparisonDimensions.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Returns all tags used by suites, scenarios, and metrics.
    public var allTags: [BenchmarkTag] {
        let tags = suites.flatMap(\.tags) + scenarios.flatMap(\.tags) + metrics.flatMap(\.tags)
        let tagsByID = Dictionary(tags.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        return tagsByID.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// Benchmark identifiers accepted by performance change notes for this dashboard catalog.
    public var benchmarkIDRegistry: BenchmarkIDRegistry {
        BenchmarkIDRegistry(catalog: self)
    }

    /// Returns a suite by stable identifier when present.
    public func suite(withID id: BenchmarkSuite.ID?) -> BenchmarkSuite? {
        guard let id else {
            return nil
        }

        return suites.first { $0.id == id }
    }

    /// Returns a scenario by stable identifier when present.
    public func scenario(withID id: BenchmarkScenario.ID?) -> BenchmarkScenario? {
        guard let id else {
            return nil
        }

        return scenarios.first { $0.id == id }
    }

    /// Returns a metric by stable identifier when present.
    public func metric(withID id: BenchmarkMetric.ID?) -> BenchmarkMetric? {
        guard let id else {
            return nil
        }

        return metrics.first { $0.id == id }
    }

    /// Returns a comparison dimension by stable identifier when present.
    public func comparisonDimension(withID id: BenchmarkComparisonDimension.ID?) -> BenchmarkComparisonDimension? {
        guard let id else {
            return nil
        }

        return comparisonDimensions.first { $0.id == id }
    }

    /// Returns a cohort by stable identifier when present.
    public func cohort(withID id: BenchmarkCohort.ID?) -> BenchmarkCohort? {
        guard let id else {
            return nil
        }

        return cohorts.first { $0.id == id }
    }

    /// Returns scenarios for a suite ordered by display name.
    public func scenarios(in suiteID: BenchmarkSuite.ID?) -> [BenchmarkScenario] {
        scenarios
            .filter { scenario in
                suiteID == nil || scenario.suiteID == suiteID
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Returns comparison dimensions scoped to a scenario presentation when available.
    public func comparisonDimensions(for scenarioID: BenchmarkScenario.ID?) -> [BenchmarkComparisonDimension] {
        guard
            let scenarioID,
            let presentation = scenario(withID: scenarioID)?.presentation,
            presentation.comparisonDimensionIDs.isEmpty == false
        else {
            return sortedComparisonDimensions
        }

        let dimensionsByID = Dictionary(
            comparisonDimensions.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let scopedDimensions = presentation.comparisonDimensionIDs.compactMap { dimensionsByID[$0] }
        return scopedDimensions.isEmpty ? sortedComparisonDimensions : scopedDimensions
    }
}

/// The dashboard-level presentation used by generic benchmark renderers.
public struct BenchmarkDashboardPresentation: Hashable, Sendable {
    /// The navigation title displayed by the dashboard.
    public var title: String

    /// The history scope used for baseline values.
    public var baseline: BenchmarkDashboardHistoryScope

    /// The history scope used for current values.
    public var current: BenchmarkDashboardHistoryScope

    /// The archive filter used when the dashboard first appears.
    public var initialArchiveFilter: BenchmarkArchiveFilter

    /// The comparison dimensions available to the dashboard.
    public var comparisonDimensions: [BenchmarkComparisonDimension]

    /// The sample count below which rows receive a low-sample note.
    public var lowSampleThreshold: Int

    /// The policy used when evaluating post-run benchmark insights.
    public var insightEvaluationPolicy: BenchmarkInsightEvaluationPolicy

    /// The policy used when evaluating multi-build benchmark trends.
    public var trendEvaluationPolicy: BenchmarkTrendEvaluationPolicy

    /// Creates dashboard presentation configuration.
    public init(
        title: String = "Benchmark Dashboard",
        baseline: BenchmarkDashboardHistoryScope = BenchmarkDashboardHistoryScope(name: "Baseline"),
        current: BenchmarkDashboardHistoryScope = BenchmarkDashboardHistoryScope(name: "Current"),
        initialArchiveFilter: BenchmarkArchiveFilter = .active,
        comparisonDimensions: [BenchmarkComparisonDimension] = [],
        lowSampleThreshold: Int = 2,
        insightEvaluationPolicy: BenchmarkInsightEvaluationPolicy = .default,
        trendEvaluationPolicy: BenchmarkTrendEvaluationPolicy = .default
    ) {
        self.title = title
        self.baseline = baseline
        self.current = current
        self.initialArchiveFilter = initialArchiveFilter
        self.comparisonDimensions = comparisonDimensions
        self.lowSampleThreshold = lowSampleThreshold
        self.insightEvaluationPolicy = insightEvaluationPolicy
        self.trendEvaluationPolicy = trendEvaluationPolicy
    }
}
