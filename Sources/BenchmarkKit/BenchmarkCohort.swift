import Foundation

/// A canonical envelope facet on which a cohort can filter.
///
/// Facets are stable string keys backed by `BenchmarkEnvironment` fields and bundled
/// envelope extras. Hosts compose cohorts in terms of these keys instead of reaching
/// into the envelope directly.
public struct BenchmarkEnvelopeFacet: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral,
    CustomStringConvertible
{
    /// The persisted facet key.
    public let rawValue: String

    /// Creates a facet from a raw key.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a facet from a raw key.
    public init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    /// Creates a facet from a string literal.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// A human-readable representation of the facet.
    public var description: String {
        rawValue
    }

    /// The device hardware model identifier (`BenchmarkEnvironment.deviceModel`).
    public static let deviceModel: Self = "environment.deviceModel"

    /// The OS marketing version (`BenchmarkEnvironment.osVersion`).
    public static let osVersion: Self = "environment.osVersion"

    /// The host bundle short version (`BenchmarkEnvironment.bundleShortVersion`).
    public static let bundleShortVersion: Self = "environment.bundleShortVersion"

    /// The host bundle build number (`BenchmarkEnvironment.bundleBuildNumber`).
    public static let bundleBuildNumber: Self = "environment.bundleBuildNumber"

    /// The build scheme label (`BenchmarkEnvironment.scheme`).
    public static let scheme: Self = "environment.scheme"

    /// Whether the run was captured in a simulator (`"true"` / `"false"`).
    public static let isSimulator: Self = "environment.isSimulator"

    /// The BenchmarkKit framework version that produced the record.
    public static let benchmarkKitVersion: Self = "environment.benchmarkKitVersion"

    /// Returns the string value of the facet for a given envelope, or `nil` when absent.
    ///
    /// Built-in facets read from `BenchmarkEnvironment`; any other key reads from
    /// `BenchmarkEnvelope.extras`, which is where hosts inject account hashes and
    /// experiment flags via `BenchmarkEnvelopeProvider`.
    public func value(in envelope: BenchmarkEnvelope) -> String? {
        switch self {
        case .deviceModel: envelope.environment.deviceModel
        case .osVersion: envelope.environment.osVersion
        case .bundleShortVersion: envelope.environment.bundleShortVersion
        case .bundleBuildNumber: envelope.environment.bundleBuildNumber
        case .scheme: envelope.environment.scheme
        case .isSimulator: envelope.environment.isSimulator ? "true" : "false"
        case .benchmarkKitVersion: envelope.environment.benchmarkKitVersion
        default: envelope.extras[rawValue]
        }
    }
}

/// A saved filter expression over a run's tags, envelope facets, and title hash.
///
/// All declared clauses are AND-combined. Inside a single clause, the accepted-value
/// set is OR-combined. Empty clauses are ignored. A filter with no declared clauses
/// matches every run.
public struct BenchmarkCohortFilter: Hashable, Codable, Sendable {
    /// Tag IDs that every matching run must carry.
    public var requiredTagIDs: Set<BenchmarkTag.ID>

    /// Tag IDs of which a matching run must carry at least one (empty = no constraint).
    public var anyTagIDs: Set<BenchmarkTag.ID>

    /// Tag IDs that a matching run must not carry.
    public var excludedTagIDs: Set<BenchmarkTag.ID>

    /// Title hashes accepted by the filter (empty = no constraint).
    public var titleHashes: Set<String>

    /// Envelope facet allow-lists; for each facet, a run's value must be in the set.
    public var envelopeFacets: [BenchmarkEnvelopeFacet: Set<String>]

    /// Creates a cohort filter. Defaults match every run.
    public init(
        requiredTagIDs: Set<BenchmarkTag.ID> = [],
        anyTagIDs: Set<BenchmarkTag.ID> = [],
        excludedTagIDs: Set<BenchmarkTag.ID> = [],
        titleHashes: Set<String> = [],
        envelopeFacets: [BenchmarkEnvelopeFacet: Set<String>] = [:]
    ) {
        self.requiredTagIDs = requiredTagIDs
        self.anyTagIDs = anyTagIDs
        self.excludedTagIDs = excludedTagIDs
        self.titleHashes = titleHashes
        self.envelopeFacets = envelopeFacets
    }

    /// Returns whether a run satisfies every declared clause.
    public func matches(_ run: BenchmarkRun) -> Bool {
        let runTagIDs = Set(run.tags.map(\.id))

        guard requiredTagIDs.isSubset(of: runTagIDs) else { return false }

        if !anyTagIDs.isEmpty, anyTagIDs.isDisjoint(with: runTagIDs) {
            return false
        }

        if !excludedTagIDs.isDisjoint(with: runTagIDs) { return false }

        if !titleHashes.isEmpty {
            guard let hash = run.titleHash, titleHashes.contains(hash) else { return false }
        }

        if !envelopeFacets.isEmpty {
            guard let envelope = run.envelope else { return false }
            for (facet, accepted) in envelopeFacets {
                guard let value = facet.value(in: envelope), accepted.contains(value) else {
                    return false
                }
            }
        }

        return true
    }

    /// Canonical JSON encoder used by the round-trip helpers.
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    /// Canonical JSON decoder used by the round-trip helpers.
    public static let decoder = JSONDecoder()
}

/// A named, saved cohort of benchmark runs.
public struct BenchmarkCohort: Identifiable, Hashable, Codable, Sendable {
    /// The cohort identifier type.
    public typealias ID = BenchmarkID<Self>

    /// The stable cohort identifier.
    public var id: ID

    /// The display name for the cohort.
    public var name: String

    /// The filter expression evaluated against each run.
    public var filter: BenchmarkCohortFilter

    /// Creates a cohort.
    public init(id: ID, name: String, filter: BenchmarkCohortFilter) {
        self.id = id
        self.name = name
        self.filter = filter
    }

    /// Returns whether a run belongs to the cohort.
    public func contains(_ run: BenchmarkRun) -> Bool {
        filter.matches(run)
    }
}

/// The conservative identity used to compare benchmark runs across history.
///
/// A comparable group requires a scenario fingerprint, build number, and device
/// model so unrelated scenario shapes, app builds, and devices do not collapse
/// into one trend bucket.
public struct BenchmarkComparableRunGroupKey: Hashable, Codable, Sendable {
    /// The exact scenario shape and fuzzy bucket captured by the run.
    public var scenarioFingerprint: BenchmarkScenarioFingerprint

    /// The host bundle short version when the envelope captured one.
    public var bundleShortVersion: String?

    /// The host bundle build number.
    public var bundleBuildNumber: String

    /// The device hardware model identifier.
    public var deviceModel: String

    /// Whether the run was captured in a simulator.
    public var isSimulator: Bool

    /// Creates a comparable run group key.
    public init(
        scenarioFingerprint: BenchmarkScenarioFingerprint,
        bundleShortVersion: String? = nil,
        bundleBuildNumber: String,
        deviceModel: String,
        isSimulator: Bool
    ) {
        self.scenarioFingerprint = scenarioFingerprint
        self.bundleShortVersion = bundleShortVersion
        self.bundleBuildNumber = bundleBuildNumber
        self.deviceModel = deviceModel
        self.isSimulator = isSimulator
    }

    /// Creates a group key from a run, or `nil` when required comparison facets are absent.
    public init?(run: BenchmarkRun) {
        guard
            let scenarioFingerprint = run.scenarioFingerprint,
            let environment = run.envelope?.environment,
            let bundleBuildNumber = environment.bundleBuildNumber.nonEmptyBenchmarkFacetValue,
            let deviceModel = environment.deviceModel.nonEmptyBenchmarkFacetValue
        else {
            return nil
        }

        self.init(
            scenarioFingerprint: scenarioFingerprint,
            bundleShortVersion: environment.bundleShortVersion.nonEmptyBenchmarkFacetValue,
            bundleBuildNumber: bundleBuildNumber,
            deviceModel: deviceModel,
            isSimulator: environment.isSimulator
        )
    }

    /// Returns whether a run belongs to this comparable group.
    public func contains(_ run: BenchmarkRun) -> Bool {
        Self(run: run) == self
    }
}

/// A set of runs that are safe to compare as one trend bucket.
public struct BenchmarkComparableRunGroup: Hashable, Sendable {
    /// The comparable identity shared by every run in the group.
    public var key: BenchmarkComparableRunGroupKey

    /// Runs in the group, sorted newest first.
    public var runs: [BenchmarkRun]

    /// Creates a comparable run group.
    public init(key: BenchmarkComparableRunGroupKey, runs: [BenchmarkRun]) {
        self.key = key
        self.runs = runs.sortedByBenchmarkStartedAtDescending()
    }

    /// Returns the newest run older than the reference run.
    public func previousRun(before referenceRun: BenchmarkRun) -> BenchmarkRun? {
        guard key.contains(referenceRun) else { return nil }

        return runs.first { candidateRun in
            candidateRun.id != referenceRun.id &&
                candidateRun.startedAt < referenceRun.startedAt
        }
    }

    /// Returns the newest runs in this comparable group.
    public func lastRuns(limit: Int) -> [BenchmarkRun] {
        Array(runs.prefix(Swift.max(0, limit)))
    }
}

// MARK: - Query helpers

public extension BenchmarkRunQuery {
    /// Returns a copy of the query refined by a cohort filter.
    ///
    /// The cohort's required tag IDs are added to `tagIDs`. Other cohort clauses
    /// (title hash, envelope facets, exclusions) cannot be expressed in the base
    /// query and must be applied by the caller via `BenchmarkCohort.contains(_:)`.
    func refined(by cohort: BenchmarkCohort) -> BenchmarkRunQuery {
        var copy = self
        copy.tagIDs.formUnion(cohort.filter.requiredTagIDs)
        return copy
    }
}

public extension BenchmarkHistoryDataSource {
    /// Loads the runs in a cohort.
    func runs(
        in cohort: BenchmarkCohort,
        baseQuery: BenchmarkRunQuery = BenchmarkRunQuery()
    ) async throws -> [BenchmarkRun] {
        let candidates = try await runs(matching: baseQuery.refined(by: cohort))
        return candidates.filter(cohort.contains)
    }

    /// Loads runs grouped by cohort, preserving the input cohort order.
    ///
    /// Cohorts are not assumed to be disjoint; a run that matches two cohorts will
    /// appear in both groups, which is the contract the dashboard's "Compare cohorts"
    /// affordance relies on.
    func runs(
        grouping cohorts: [BenchmarkCohort],
        baseQuery: BenchmarkRunQuery = BenchmarkRunQuery()
    ) async throws -> [(
        cohort: BenchmarkCohort,
        runs: [BenchmarkRun]
    )] {
        var result: [(cohort: BenchmarkCohort, runs: [BenchmarkRun])] = []
        result.reserveCapacity(cohorts.count)
        for cohort in cohorts {
            let runs = try await runs(in: cohort, baseQuery: baseQuery)
            result.append((cohort, runs))
        }
        return result
    }

    /// Loads runs grouped into comparable trend buckets.
    ///
    /// Runs missing a scenario fingerprint, bundle build number, or device model
    /// are excluded because they cannot be safely compared with other history.
    func comparableRunGroups(matching query: BenchmarkRunQuery = BenchmarkRunQuery()) async throws
        -> [BenchmarkComparableRunGroup]
    {
        let candidateRuns = try await runs(matching: query)
        let runsByKey = Dictionary(grouping: candidateRuns) { run in
            BenchmarkComparableRunGroupKey(run: run)
        }

        return runsByKey.compactMap { key, runs -> BenchmarkComparableRunGroup? in
            guard let key else { return nil }
            return BenchmarkComparableRunGroup(key: key, runs: runs)
        }
        .sorted { lhs, rhs in
            guard let lhsStartedAt = lhs.runs.first?.startedAt else { return false }
            guard let rhsStartedAt = rhs.runs.first?.startedAt else { return true }

            if lhsStartedAt == rhsStartedAt {
                return lhs.key.stableSortValue < rhs.key.stableSortValue
            }

            return lhsStartedAt > rhsStartedAt
        }
    }

    /// Loads runs that belong to a comparable trend bucket.
    func runs(
        inComparableGroup key: BenchmarkComparableRunGroupKey,
        baseQuery: BenchmarkRunQuery = BenchmarkRunQuery()
    ) async throws -> [BenchmarkRun] {
        let candidateRuns = try await runs(matching: baseQuery)
        return candidateRuns
            .filter(key.contains)
            .sortedByBenchmarkStartedAtDescending()
    }
}

private extension String {
    var nonEmptyBenchmarkFacetValue: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private extension BenchmarkComparableRunGroupKey {
    var stableSortValue: String {
        [
            bundleShortVersion ?? "",
            bundleBuildNumber,
            deviceModel,
            isSimulator ? "simulator" : "device",
            scenarioFingerprint.stableSortValue
        ].joined(separator: "\u{1F}")
    }
}

private extension BenchmarkScenarioFingerprint {
    var stableSortValue: String {
        [
            strictGates.values.stableSortValue,
            fuzzyBucket.values.stableSortValue
        ].joined(separator: "\u{1E}")
    }
}

private extension [BenchmarkScenarioFingerprintValue] {
    var stableSortValue: String {
        map { "\($0.dimension.rawValue)=\($0.value)" }.joined(separator: "\u{1D}")
    }
}

private extension [BenchmarkRun] {
    func sortedByBenchmarkStartedAtDescending() -> [BenchmarkRun] {
        sorted { lhs, rhs in
            if lhs.startedAt == rhs.startedAt {
                return lhs.id.rawValue < rhs.id.rawValue
            }

            return lhs.startedAt > rhs.startedAt
        }
    }
}
