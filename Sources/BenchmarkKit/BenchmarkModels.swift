import Foundation

/// A group of benchmark scenarios that share a product or feature boundary.
public struct BenchmarkSuite: Identifiable, Hashable, Codable, Sendable {
    /// The suite identifier type.
    public typealias ID = BenchmarkID<Self>

    /// The stable suite identifier.
    public var id: ID

    /// The display name for the suite.
    public var name: String

    /// Tags that describe the suite.
    public var tags: Set<BenchmarkTag>

    /// Additional string metadata for consumers that need lightweight context.
    public var metadata: [String: String]

    /// Creates a benchmark suite.
    public init(
        id: ID,
        name: String,
        tags: Set<BenchmarkTag> = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.tags = tags
        self.metadata = metadata
    }
}

/// A single stable dimension value inside a scenario fingerprint.
public struct BenchmarkScenarioFingerprintValue: Hashable, Codable, Sendable {
    /// The dimension described by the value.
    public var dimension: BenchmarkScenarioFingerprintDimension

    /// The normalized value for the dimension.
    public var value: String

    /// Creates a scenario fingerprint value.
    public init(dimension: BenchmarkScenarioFingerprintDimension, value: String) {
        self.dimension = dimension
        self.value = value
    }
}

/// Exact gates that must match before two scenario runs can be compared.
///
/// Put dimensions that would change the measured workflow semantics here, such as
/// workflow family, media kind, export kind, export format, or codec. Values are
/// canonicalized by dimension so equality and persistence stay stable.
public struct BenchmarkScenarioStrictGates: Hashable, Codable, Sendable {
    /// Canonical gate values sorted by dimension.
    public var values: [BenchmarkScenarioFingerprintValue]

    /// Creates strict gates from dimension values.
    public init(_ values: [BenchmarkScenarioFingerprintValue] = []) {
        self.values = Self.canonicalValues(from: values)
    }

    /// Creates strict gates from key-value pairs.
    public init(_ valuesByDimension: [BenchmarkScenarioFingerprintDimension: String]) {
        self.init(valuesByDimension.map { dimension, value in
            BenchmarkScenarioFingerprintValue(dimension: dimension, value: value)
        })
    }

    /// Decodes and canonicalizes strict gate values.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(try container.decode([BenchmarkScenarioFingerprintValue].self, forKey: .values))
    }

    /// Returns the value for a dimension when present.
    public func value(for dimension: BenchmarkScenarioFingerprintDimension) -> String? {
        values.first { $0.dimension == dimension }?.value
    }

    /// Returns whether these gates allow comparison with another set of gates.
    public func permitsComparison(with other: Self) -> Bool {
        !values.isEmpty && values == other.values
    }

    private static func canonicalValues(from values: [BenchmarkScenarioFingerprintValue]) -> [BenchmarkScenarioFingerprintValue] {
        let valuesByDimension = Dictionary(values.map { ($0.dimension, $0.value) }, uniquingKeysWith: { _, new in new })
        return valuesByDimension
            .map { dimension, value in BenchmarkScenarioFingerprintValue(dimension: dimension, value: value) }
            .sorted {
                if $0.dimension.rawValue == $1.dimension.rawValue {
                    return $0.value < $1.value
                }
                return $0.dimension.rawValue < $1.dimension.rawValue
            }
    }

    private enum CodingKeys: String, CodingKey {
        case values
    }
}

/// A coarse bucket that groups nearby variants of an otherwise comparable scenario.
///
/// Use bucketed dimensions for tolerated variance such as small media-count,
/// duration, or size differences. Exact workflow/media/export gates belong in
/// `BenchmarkScenarioStrictGates` so unrelated cases cannot collapse together.
public struct BenchmarkScenarioFuzzyBucket: Hashable, Codable, Sendable {
    /// Canonical bucket values sorted by dimension.
    public var values: [BenchmarkScenarioFingerprintValue]

    /// Creates a fuzzy bucket from dimension values.
    public init(_ values: [BenchmarkScenarioFingerprintValue] = []) {
        self.values = BenchmarkScenarioStrictGates(values).values
    }

    /// Creates a fuzzy bucket from key-value pairs.
    public init(_ valuesByDimension: [BenchmarkScenarioFingerprintDimension: String]) {
        self.init(valuesByDimension.map { dimension, value in
            BenchmarkScenarioFingerprintValue(dimension: dimension, value: value)
        })
    }

    /// Decodes and canonicalizes fuzzy bucket values.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(try container.decode([BenchmarkScenarioFingerprintValue].self, forKey: .values))
    }

    /// Returns the value for a dimension when present.
    public func value(for dimension: BenchmarkScenarioFingerprintDimension) -> String? {
        values.first { $0.dimension == dimension }?.value
    }

    private enum CodingKeys: String, CodingKey {
        case values
    }
}

/// A stable model used to decide whether scenario runs are comparable.
public struct BenchmarkScenarioFingerprint: Hashable, Codable, Sendable {
    /// Exact gates that must match before comparison is allowed.
    public var strictGates: BenchmarkScenarioStrictGates

    /// Coarse bucket values that group nearby variants after strict gates match.
    public var fuzzyBucket: BenchmarkScenarioFuzzyBucket

    /// Creates a scenario fingerprint.
    public init(
        strictGates: BenchmarkScenarioStrictGates,
        fuzzyBucket: BenchmarkScenarioFuzzyBucket = BenchmarkScenarioFuzzyBucket()
    ) {
        self.strictGates = strictGates
        self.fuzzyBucket = fuzzyBucket
    }

    /// Returns whether another fingerprint represents a comparable workflow.
    public func isComparable(with other: Self) -> Bool {
        strictGates.permitsComparison(with: other.strictGates)
    }

    /// Returns whether another fingerprint is in the same fuzzy bucket.
    public func isInSameFuzzyBucket(as other: Self) -> Bool {
        isComparable(with: other) && fuzzyBucket == other.fuzzyBucket
    }
}

/// A single measurable workflow or case within a benchmark suite.
public struct BenchmarkScenario: Identifiable, Hashable, Codable, Sendable {
    /// The scenario identifier type.
    public typealias ID = BenchmarkID<Self>

    /// The stable scenario identifier.
    public var id: ID

    /// The suite that owns this scenario.
    public var suiteID: BenchmarkSuite.ID

    /// The display name for the scenario.
    public var name: String

    /// Tags that describe the scenario.
    public var tags: Set<BenchmarkTag>

    /// Additional string metadata for consumers that need lightweight context.
    public var metadata: [String: String]

    /// Stable scenario fingerprint used for conservative comparable-run matching.
    public var fingerprint: BenchmarkScenarioFingerprint?

    /// Presentation hints for generic benchmark dashboard renderers.
    public var presentation: BenchmarkScenarioPresentation?

    /// Creates a benchmark scenario.
    public init(
        id: ID,
        suiteID: BenchmarkSuite.ID,
        name: String,
        tags: Set<BenchmarkTag> = [],
        metadata: [String: String] = [:],
        fingerprint: BenchmarkScenarioFingerprint? = nil,
        presentation: BenchmarkScenarioPresentation? = nil
    ) {
        self.id = id
        self.suiteID = suiteID
        self.name = name
        self.tags = tags
        self.metadata = metadata
        self.fingerprint = fingerprint
        self.presentation = presentation
    }
}

/// A metric unit represented by a stable raw string.
public struct BenchmarkMetricUnit: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    /// The persisted unit value.
    public let rawValue: String

    /// Creates a metric unit from a raw string value.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a metric unit from a raw string value.
    public init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    /// Creates a metric unit from a string literal.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// A human-readable representation of the unit.
    public var description: String {
        rawValue
    }

    /// Milliseconds.
    public static let milliseconds = Self("ms")

    /// Seconds.
    public static let seconds = Self("s")

    /// Frames per second.
    public static let framesPerSecond = Self("fps")

    /// Bytes.
    public static let bytes = Self("bytes")

    /// A unitless count.
    public static let count = Self("count")

    /// A ratio value.
    public static let ratio = Self("ratio")

    /// A score value.
    public static let score = Self("score")
}

/// The preferred direction for a benchmark metric.
public enum BenchmarkMetricDirection: String, Hashable, Codable, Sendable {
    /// Lower values are better.
    case lowerIsBetter

    /// Higher values are better.
    case higherIsBetter

    /// Changes should be shown without assigning improvement or regression.
    case neutral
}

/// A numeric value that can be sampled during a benchmark run.
public struct BenchmarkMetric: Identifiable, Hashable, Codable, Sendable {
    /// The metric identifier type.
    public typealias ID = BenchmarkID<Self>

    /// The stable metric identifier.
    public var id: ID

    /// The display name for the metric.
    public var name: String

    /// The unit used to display sampled values.
    public var unit: BenchmarkMetricUnit

    /// The direction used to classify deltas.
    public var direction: BenchmarkMetricDirection

    /// Tags that describe the metric.
    public var tags: Set<BenchmarkTag>

    /// Additional string metadata for consumers that need lightweight context.
    public var metadata: [String: String]

    /// Creates a benchmark metric.
    public init(
        id: ID,
        name: String,
        unit: BenchmarkMetricUnit,
        direction: BenchmarkMetricDirection = .neutral,
        tags: Set<BenchmarkTag> = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.unit = unit
        self.direction = direction
        self.tags = tags
        self.metadata = metadata
    }
}

/// A product or technical area associated with a performance change note.
public struct BenchmarkPerformanceChangeArea: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    /// The persisted area key.
    public let rawValue: String

    /// Creates a performance change area from a raw key.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a performance change area from a raw key.
    public init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    /// Creates a performance change area from a string literal.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// A human-readable representation of the area.
    public var description: String {
        rawValue
    }

    /// App launch and startup work.
    public static let launch: Self = "launch"

    /// Scrolling, lists, feeds, and gesture-driven navigation.
    public static let scrolling: Self = "scrolling"

    /// Media import, editing, rendering, or export work.
    public static let media: Self = "media"

    /// Data loading, persistence, sync, or caching work.
    public static let data: Self = "data"

    /// Benchmark recording, instrumentation, or measurement work.
    public static let instrumentation: Self = "instrumentation"
}

/// The kind of code or configuration change described by a performance note.
public enum BenchmarkPerformanceChangeType: String, CaseIterable, Hashable, Codable, Sendable {
    /// A user-visible feature or workflow addition.
    case feature

    /// An intentional performance optimization.
    case optimization

    /// A structural code change intended to preserve behavior.
    case refactor

    /// A configuration, entitlement, build setting, or runtime flag change.
    case configuration

    /// A dependency, SDK, package, or toolchain change.
    case dependency

    /// A benchmark, logging, tracing, or measurement change.
    case instrumentation

    /// A guarded experiment or A/B variant.
    case experiment
}

/// The expected performance direction of a change note.
public enum BenchmarkPerformanceExpectedImpact: String, CaseIterable, Hashable, Codable, Sendable {
    /// The change is expected to improve the affected benchmarks.
    case improvesPerformance

    /// The change is expected to regress the affected benchmarks.
    case regressesPerformance

    /// The change is expected to have mixed effects across benchmarks.
    case mixed

    /// The change should be visible in benchmarks without a known direction.
    case neutral

    /// The performance impact is not known yet.
    case unknown
}

/// The performance risk level assigned to a change note.
public enum BenchmarkPerformanceChangeRisk: String, CaseIterable, Hashable, Codable, Sendable {
    /// Low likelihood or low severity of benchmark movement.
    case low

    /// Meaningful benchmark movement is possible.
    case medium

    /// Meaningful benchmark movement is likely or high severity.
    case high

    /// Risk has not been classified yet.
    case unknown
}

/// The app build where a performance change was introduced or first observed.
public struct BenchmarkPerformanceChangeBuild: Hashable, Codable, Sendable {
    /// The application bundle build number, e.g. `4216`.
    public var bundleBuildNumber: String

    /// The application marketing version, e.g. `4.8.0`.
    public var bundleShortVersion: String?

    /// The source revision associated with the build, when available.
    public var sourceRevision: String?

    /// Additional string metadata for consumers that need lightweight context.
    public var metadata: [String: String]

    /// Creates a performance change build reference.
    public init(
        bundleBuildNumber: String,
        bundleShortVersion: String? = nil,
        sourceRevision: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.bundleBuildNumber = bundleBuildNumber
        self.bundleShortVersion = bundleShortVersion
        self.sourceRevision = sourceRevision
        self.metadata = metadata
    }
}

/// A benchmark reference affected by a performance change note.
public struct BenchmarkPerformanceChangeAffectedBenchmark: Hashable, Codable, Sendable {
    /// The affected suite, when the note applies to a known suite.
    public var suiteID: BenchmarkSuite.ID?

    /// The affected scenario, when the note applies to a known scenario.
    public var scenarioID: BenchmarkScenario.ID?

    /// The affected metric, when the note applies to a known metric.
    public var metricID: BenchmarkMetric.ID?

    /// The affected scenario fingerprint, when a note targets comparable-run cohorts.
    public var scenarioFingerprint: BenchmarkScenarioFingerprint?

    /// Additional string metadata for consumers that need lightweight context.
    public var metadata: [String: String]

    /// Creates an affected benchmark reference.
    public init(
        suiteID: BenchmarkSuite.ID? = nil,
        scenarioID: BenchmarkScenario.ID? = nil,
        metricID: BenchmarkMetric.ID? = nil,
        scenarioFingerprint: BenchmarkScenarioFingerprint? = nil,
        metadata: [String: String] = [:]
    ) {
        self.suiteID = suiteID
        self.scenarioID = scenarioID
        self.metricID = metricID
        self.scenarioFingerprint = scenarioFingerprint
        self.metadata = metadata
    }
}

/// A structured note that annotates expected performance movement for a build.
public struct BenchmarkPerformanceChangeNote: Identifiable, Hashable, Codable, Sendable {
    /// The performance change note identifier type.
    public typealias ID = BenchmarkID<Self>

    /// The stable note identifier.
    public var id: ID

    /// The product or technical area associated with the change.
    public var area: BenchmarkPerformanceChangeArea

    /// The kind of code or configuration change.
    public var changeType: BenchmarkPerformanceChangeType

    /// A concise human-readable summary of the change.
    public var summary: String

    /// The expected performance direction.
    public var expectedImpact: BenchmarkPerformanceExpectedImpact

    /// Benchmarks that may be affected by the change.
    public var affectedBenchmarks: [BenchmarkPerformanceChangeAffectedBenchmark]

    /// The risk level assigned to this change.
    public var risk: BenchmarkPerformanceChangeRisk

    /// The build where the change was introduced or first observed.
    public var buildIntroduced: BenchmarkPerformanceChangeBuild

    /// Validation context, such as experiment checks or profiling notes.
    public var validationNotes: [String]

    /// Additional string metadata for consumers that need lightweight context.
    public var metadata: [String: String]

    /// Creates a performance change note.
    public init(
        id: ID,
        area: BenchmarkPerformanceChangeArea,
        changeType: BenchmarkPerformanceChangeType,
        summary: String,
        expectedImpact: BenchmarkPerformanceExpectedImpact,
        affectedBenchmarks: [BenchmarkPerformanceChangeAffectedBenchmark],
        risk: BenchmarkPerformanceChangeRisk,
        buildIntroduced: BenchmarkPerformanceChangeBuild,
        validationNotes: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.area = area
        self.changeType = changeType
        self.summary = summary
        self.expectedImpact = expectedImpact
        self.affectedBenchmarks = affectedBenchmarks
        self.risk = risk
        self.buildIntroduced = buildIntroduced
        self.validationNotes = validationNotes
        self.metadata = metadata
    }
}

/// Whether benchmark history should be considered active or archived.
public enum BenchmarkArchiveState: String, CaseIterable, Hashable, Codable, Sendable {
    /// History that should appear in the default active benchmark view.
    case active

    /// History that has been retained but removed from the default active view.
    case archived
}

/// A recorded benchmark run.
public struct BenchmarkRun: Identifiable, Hashable, Codable, Sendable {
    /// The run identifier type.
    public typealias ID = BenchmarkID<Self>

    /// The stable run identifier.
    public var id: ID

    /// The suite measured by the run.
    public var suiteID: BenchmarkSuite.ID

    /// The scenario measured by the run.
    public var scenarioID: BenchmarkScenario.ID

    /// The time when the run started.
    public var startedAt: Date

    /// The time when the run ended.
    public var endedAt: Date?

    /// The active or archived state for the run.
    public var archiveState: BenchmarkArchiveState

    /// Tags attached to the run.
    public var tags: Set<BenchmarkTag>

    /// Additional string metadata for consumers that need lightweight context.
    public var metadata: [String: String]

    /// Structured envelope describing the device, build, and host extras for the run.
    public var envelope: BenchmarkEnvelope?

    /// Aggregate system-sample summary, when the run captured one.
    public var systemSummary: BenchmarkSystemSummary?

    /// A human override used for known-regression captures; takes precedence over the composed title.
    public var titleOverride: String?

    /// The deterministic hash of the composed title's action sequence, used for cohort grouping.
    public var titleHash: String?

    /// Stable scenario fingerprint captured for comparable-run matching.
    public var scenarioFingerprint: BenchmarkScenarioFingerprint?

    /// Creates a benchmark run.
    public init(
        id: ID,
        suiteID: BenchmarkSuite.ID,
        scenarioID: BenchmarkScenario.ID,
        startedAt: Date,
        endedAt: Date? = nil,
        archiveState: BenchmarkArchiveState = .active,
        tags: Set<BenchmarkTag> = [],
        metadata: [String: String] = [:],
        envelope: BenchmarkEnvelope? = nil,
        systemSummary: BenchmarkSystemSummary? = nil,
        titleOverride: String? = nil,
        titleHash: String? = nil,
        scenarioFingerprint: BenchmarkScenarioFingerprint? = nil
    ) {
        self.id = id
        self.suiteID = suiteID
        self.scenarioID = scenarioID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.archiveState = archiveState
        self.tags = tags
        self.metadata = metadata
        self.envelope = envelope
        self.systemSummary = systemSummary
        self.titleOverride = titleOverride
        self.titleHash = titleHash
        self.scenarioFingerprint = scenarioFingerprint
    }

    /// The elapsed time for the run when an end time is available.
    public var durationSeconds: TimeInterval? {
        endedAt.map { $0.timeIntervalSince(startedAt) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, suiteID, scenarioID, startedAt, endedAt, archiveState, tags, metadata, envelope, systemSummary, titleOverride, titleHash, scenarioFingerprint
    }

    /// Decodes a run; previously persisted runs without an envelope or title read back with those fields `nil`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(ID.self, forKey: .id)
        self.suiteID = try container.decode(BenchmarkSuite.ID.self, forKey: .suiteID)
        self.scenarioID = try container.decode(BenchmarkScenario.ID.self, forKey: .scenarioID)
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        self.archiveState = try container.decode(BenchmarkArchiveState.self, forKey: .archiveState)
        self.tags = try container.decode(Set<BenchmarkTag>.self, forKey: .tags)
        self.metadata = try container.decode([String: String].self, forKey: .metadata)
        self.envelope = try container.decodeIfPresent(BenchmarkEnvelope.self, forKey: .envelope)
        self.systemSummary = try container.decodeIfPresent(BenchmarkSystemSummary.self, forKey: .systemSummary)
        self.titleOverride = try container.decodeIfPresent(String.self, forKey: .titleOverride)
        self.titleHash = try container.decodeIfPresent(String.self, forKey: .titleHash)
        self.scenarioFingerprint = try container.decodeIfPresent(BenchmarkScenarioFingerprint.self, forKey: .scenarioFingerprint)
    }
}

/// A single numeric metric observation captured during a benchmark run.
public struct BenchmarkSample: Identifiable, Hashable, Codable, Sendable {
    /// The sample identifier type.
    public typealias ID = BenchmarkID<Self>

    /// The stable sample identifier.
    public var id: ID

    /// The run that produced the sample.
    public var runID: BenchmarkRun.ID

    /// The suite measured by the sample.
    public var suiteID: BenchmarkSuite.ID

    /// The scenario measured by the sample.
    public var scenarioID: BenchmarkScenario.ID

    /// The metric measured by the sample.
    public var metricID: BenchmarkMetric.ID

    /// The numeric measurement.
    public var value: Double

    /// The time when the measurement was captured.
    public var measuredAt: Date

    /// Tags attached to the sample.
    public var tags: Set<BenchmarkTag>

    /// Additional string metadata for consumers that need lightweight context.
    public var metadata: [String: String]

    /// Creates a benchmark sample.
    public init(
        id: ID,
        runID: BenchmarkRun.ID,
        suiteID: BenchmarkSuite.ID,
        scenarioID: BenchmarkScenario.ID,
        metricID: BenchmarkMetric.ID,
        value: Double,
        measuredAt: Date,
        tags: Set<BenchmarkTag> = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.runID = runID
        self.suiteID = suiteID
        self.scenarioID = scenarioID
        self.metricID = metricID
        self.value = value
        self.measuredAt = measuredAt
        self.tags = tags
        self.metadata = metadata
    }
}
