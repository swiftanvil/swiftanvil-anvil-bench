import Foundation

/// Summary statistics for benchmark samples with a shared metric.
public struct BenchmarkSampleSummary: Hashable, Codable, Sendable {
    /// The number of samples included in the summary.
    public var count: Int

    /// The arithmetic mean of included sample values.
    public var mean: Double?

    /// The minimum included sample value.
    public var minimum: Double?

    /// The maximum included sample value.
    public var maximum: Double?

    /// The latest included sample value by measurement time.
    public var latest: Double?

    /// Creates a sample summary.
    public init(count: Int, mean: Double?, minimum: Double?, maximum: Double?, latest: Double?) {
        self.count = count
        self.mean = mean
        self.minimum = minimum
        self.maximum = maximum
        self.latest = latest
    }

    /// Creates a summary from samples.
    public init(samples: [BenchmarkSample]) {
        let values = samples.map(\.value)
        let latestSample = samples.max { $0.measuredAt < $1.measuredAt }

        self.init(
            count: values.count,
            mean: values.isEmpty ? nil : values.reduce(0, +) / Double(values.count),
            minimum: values.min(),
            maximum: values.max(),
            latest: latestSample?.value
        )
    }

    /// An empty sample summary.
    public static let empty = Self(
        count: 0,
        mean: nil,
        minimum: nil,
        maximum: nil,
        latest: nil
    )
}

/// The numeric difference between baseline and current values.
public struct BenchmarkDelta: Hashable, Codable, Sendable {
    /// The current value minus the baseline value.
    public var absolute: Double

    /// The percent change from baseline, when baseline is nonzero.
    public var percentage: Double?

    /// Creates a benchmark delta.
    public init(baseline: Double, current: Double) {
        absolute = current - baseline
        percentage = baseline == 0 ? nil : (absolute / abs(baseline)) * 100
    }
}

/// Whether a comparison has enough data to compute a delta.
public enum BenchmarkComparisonDataState: String, Hashable, Codable, Sendable {
    /// Baseline and current data are both available.
    case complete

    /// Baseline data is missing.
    case missingBaseline

    /// Current data is missing.
    case missingCurrent

    /// Baseline and current data are both missing.
    case missingBaselineAndCurrent
}

/// Directional interpretation of benchmark movement.
public enum BenchmarkTrendDirection: String, Hashable, Codable, Sendable {
    /// The current value is better than the baseline for the metric direction.
    case improved

    /// The current value is worse than the baseline for the metric direction.
    case regressed

    /// The current value is effectively unchanged from the baseline.
    case unchanged

    /// There is not enough data to classify movement.
    case unavailable
}

/// A trend classification and the delta used to compute it.
public struct BenchmarkTrendSummary: Hashable, Codable, Sendable {
    /// The interpreted direction of movement.
    public var direction: BenchmarkTrendDirection

    /// The delta that produced the direction.
    public var delta: BenchmarkDelta?

    /// The number of samples considered by the trend.
    public var sampleCount: Int

    /// Creates a trend summary.
    public init(direction: BenchmarkTrendDirection, delta: BenchmarkDelta?, sampleCount: Int) {
        self.direction = direction
        self.delta = delta
        self.sampleCount = sampleCount
    }

    /// Creates an unavailable trend summary.
    public static func unavailable(sampleCount: Int = 0) -> Self {
        Self(direction: .unavailable, delta: nil, sampleCount: sampleCount)
    }
}

/// The higher-level shape of a metric's recent comparable history.
public enum BenchmarkTrendClassification: String, Hashable, Codable, Sendable {
    /// Recent comparable values are moving in the metric's better direction.
    case improving

    /// Recent comparable values are moving in the metric's worse direction.
    case regressing

    /// Recent comparable values changed less than the configured movement threshold.
    case stable

    /// Recent comparable values move enough in both directions that no single direction is reliable.
    case volatile

    /// The current value returned to the better side after a recent regression.
    case recovered

    /// No previous comparable run is available.
    case missingBaseline
}

/// Confidence assigned to a benchmark trend evaluation.
public enum BenchmarkTrendConfidence: String, Hashable, Codable, Sendable {
    /// Enough comparable history exists and no noisy-history flag was raised.
    case high

    /// A comparable baseline exists, but history is thin or noisy.
    case medium

    /// The evaluator could only make a weak classification.
    case low

    /// No comparable baseline is available.
    case unavailable
}

/// Non-causal qualifiers produced by the trend evaluator.
public enum BenchmarkTrendHistoryOutcome: String, Hashable, Codable, Sendable {
    /// Fewer comparable runs were available than the configured last-N window.
    case sparseHistory

    /// Recent comparable history moved in both directions past the configured threshold.
    case noisyHistory

    /// Current and baseline values are too close to call a meaningful movement.
    case suppressedSmallMovement
}

/// Tuning values for benchmark trend evaluation.
public struct BenchmarkTrendEvaluationPolicy: Hashable, Codable, Sendable {
    /// Number of comparable runs, including the current run, used for the last-N trend.
    public var lastRunCount: Int

    /// Number of comparable runs, including the current run, required for high confidence.
    public var minimumRunsForHighConfidence: Int

    /// Minimum absolute percentage movement required before a value is considered changed.
    public var minimumAbsolutePercentageChange: Double

    /// Minimum absolute raw-value movement required before a value is considered changed.
    public var minimumAbsoluteDelta: Double

    /// Creates a trend evaluation policy.
    public init(
        lastRunCount: Int = 5,
        minimumRunsForHighConfidence: Int = 4,
        minimumAbsolutePercentageChange: Double = 5,
        minimumAbsoluteDelta: Double = 0
    ) {
        self.lastRunCount = max(2, lastRunCount)
        self.minimumRunsForHighConfidence = max(2, minimumRunsForHighConfidence)
        self.minimumAbsolutePercentageChange = max(0, minimumAbsolutePercentageChange)
        self.minimumAbsoluteDelta = max(0, minimumAbsoluteDelta)
    }

    /// The default policy for multi-build benchmark trend evaluation.
    public static let `default` = Self()
}

/// A metric summary for one comparable benchmark run.
public struct BenchmarkComparableRunMetricSummary: Hashable, Codable, Sendable {
    /// The run represented by this summary.
    public var run: BenchmarkRun

    /// Metric sample statistics for the run.
    public var summary: BenchmarkSampleSummary

    /// Creates a comparable run metric summary.
    public init(run: BenchmarkRun, summary: BenchmarkSampleSummary) {
        self.run = run
        self.summary = summary
    }
}

/// A non-causal evaluation of recent comparable metric history.
public struct BenchmarkTrendEvaluation: Hashable, Codable, Sendable {
    /// The metric being evaluated.
    public var metric: BenchmarkMetric

    /// The current comparable run summary.
    public var current: BenchmarkComparableRunMetricSummary

    /// The nearest older comparable run summary, when available.
    public var previousComparable: BenchmarkComparableRunMetricSummary?

    /// The best older comparable run in the recent window, when available.
    public var bestRecent: BenchmarkComparableRunMetricSummary?

    /// The ordered comparable summaries used for the last-N trend, oldest first.
    public var lastRuns: [BenchmarkComparableRunMetricSummary]

    /// Direction from the oldest to newest value in `lastRuns`.
    public var lastRunTrend: BenchmarkTrendSummary

    /// Direction from the previous comparable value to the current value.
    public var previousComparableTrend: BenchmarkTrendSummary

    /// Direction from the best recent value to the current value.
    public var bestRecentTrend: BenchmarkTrendSummary

    /// The higher-level trend classification.
    public var classification: BenchmarkTrendClassification

    /// Confidence in the non-causal classification.
    public var confidence: BenchmarkTrendConfidence

    /// Sparse, noisy, or threshold-suppression qualifiers.
    public var outcomes: Set<BenchmarkTrendHistoryOutcome>

    /// Creates a trend evaluation.
    public init(
        metric: BenchmarkMetric,
        current: BenchmarkComparableRunMetricSummary,
        previousComparable: BenchmarkComparableRunMetricSummary?,
        bestRecent: BenchmarkComparableRunMetricSummary?,
        lastRuns: [BenchmarkComparableRunMetricSummary],
        lastRunTrend: BenchmarkTrendSummary,
        previousComparableTrend: BenchmarkTrendSummary,
        bestRecentTrend: BenchmarkTrendSummary,
        classification: BenchmarkTrendClassification,
        confidence: BenchmarkTrendConfidence,
        outcomes: Set<BenchmarkTrendHistoryOutcome>
    ) {
        self.metric = metric
        self.current = current
        self.previousComparable = previousComparable
        self.bestRecent = bestRecent
        self.lastRuns = lastRuns
        self.lastRunTrend = lastRunTrend
        self.previousComparableTrend = previousComparableTrend
        self.bestRecentTrend = bestRecentTrend
        self.classification = classification
        self.confidence = confidence
        self.outcomes = outcomes
    }

    /// Whether the evaluation should be treated as sparse.
    public var hasSparseHistory: Bool {
        outcomes.contains(.sparseHistory)
    }

    /// Whether the evaluation should be treated as noisy.
    public var hasNoisyHistory: Bool {
        outcomes.contains(.noisyHistory)
    }
}

/// Evaluates multi-build benchmark trends without claiming causality.
public struct BenchmarkTrendEvaluator: Sendable {
    /// The policy used to classify movement, confidence, and history quality.
    public var policy: BenchmarkTrendEvaluationPolicy

    /// Creates a trend evaluator.
    public init(policy: BenchmarkTrendEvaluationPolicy = .default) {
        self.policy = policy
    }

    /// Evaluates a current run against comparable history supplied by the caller.
    ///
    /// The evaluator mirrors BenchmarkKit's comparable-run lookup: envelope-backed
    /// runs require the strict comparable group key, while legacy no-envelope runs
    /// fall back to scenario fingerprint fuzzy-bucket matching.
    public func evaluation(
        for metric: BenchmarkMetric,
        currentRun: BenchmarkRun,
        historyRuns: [BenchmarkRun],
        samples: [BenchmarkSample]
    ) -> BenchmarkTrendEvaluation {
        let samplesByRunID = Dictionary(grouping: samplesMatchingMetric(in: samples, metric: metric), by: \.runID)
        let candidateRuns = historyRuns
            .filter { run in
                run.suiteID == currentRun.suiteID &&
                    run.scenarioID == currentRun.scenarioID &&
                    isComparable(run, with: currentRun)
            }

        var summaries = candidateRuns.compactMap { run -> BenchmarkComparableRunMetricSummary? in
            let summary = BenchmarkSampleSummary(samples: samplesByRunID[run.id] ?? [])
            guard summary.count > 0 else { return nil }
            return BenchmarkComparableRunMetricSummary(run: run, summary: summary)
        }

        if !summaries.contains(where: { $0.run.id == currentRun.id }) {
            let currentSummary = BenchmarkSampleSummary(samples: samplesByRunID[currentRun.id] ?? [])
            summaries.append(BenchmarkComparableRunMetricSummary(run: currentRun, summary: currentSummary))
        }

        let current = summaries.first { $0.run.id == currentRun.id } ??
            BenchmarkComparableRunMetricSummary(
                run: currentRun,
                summary: BenchmarkSampleSummary(samples: samplesByRunID[currentRun.id] ?? [])
            )
        let olderSummaries = summaries
            .filter { $0.run.id != currentRun.id && $0.run.startedAt < currentRun.startedAt }
            .sortedByBenchmarkStartedAtDescending()
        let previousComparable = olderSummaries.first
        let recentOlderSummaries = Array(olderSummaries.prefix(max(0, policy.lastRunCount - 1)))
        let bestRecent = bestSummary(in: recentOlderSummaries, metric: metric)
        let lastRuns = (recentOlderSummaries + [current])
            .sortedByBenchmarkStartedAtAscending()
        let lastRunTrend = trend(from: lastRuns, metric: metric)
        let previousComparableTrend = trend(from: previousComparable, to: current, metric: metric)
        let bestRecentTrend = trend(from: bestRecent, to: current, metric: metric)
        let outcomes = historyOutcomes(
            previousComparableTrend: previousComparableTrend,
            lastRuns: lastRuns,
            metric: metric
        )
        let classification = classification(
            previousComparableTrend: previousComparableTrend,
            lastRunTrend: lastRunTrend,
            lastRuns: lastRuns,
            outcomes: outcomes,
            metric: metric
        )
        let confidence = confidence(
            classification: classification,
            lastRuns: lastRuns,
            outcomes: outcomes
        )

        return BenchmarkTrendEvaluation(
            metric: metric,
            current: current,
            previousComparable: previousComparable,
            bestRecent: bestRecent,
            lastRuns: lastRuns,
            lastRunTrend: lastRunTrend,
            previousComparableTrend: previousComparableTrend,
            bestRecentTrend: bestRecentTrend,
            classification: classification,
            confidence: confidence,
            outcomes: outcomes
        )
    }

    private func samplesMatchingMetric(in samples: [BenchmarkSample], metric: BenchmarkMetric) -> [BenchmarkSample] {
        samples.filter { $0.metricID == metric.id }
    }

    private func isComparable(_ candidateRun: BenchmarkRun, with referenceRun: BenchmarkRun) -> Bool {
        if let referenceGroupKey = BenchmarkComparableRunGroupKey(run: referenceRun) {
            return referenceGroupKey.contains(candidateRun)
        }

        guard referenceRun.envelope == nil,
              candidateRun.envelope == nil,
              let referenceFingerprint = referenceRun.scenarioFingerprint,
              let candidateFingerprint = candidateRun.scenarioFingerprint
        else {
            return candidateRun.id == referenceRun.id
        }

        return candidateFingerprint.isInSameFuzzyBucket(as: referenceFingerprint)
    }

    private func bestSummary(
        in summaries: [BenchmarkComparableRunMetricSummary],
        metric: BenchmarkMetric
    ) -> BenchmarkComparableRunMetricSummary? {
        summaries
            .filter { $0.summary.mean != nil }
            .sorted { lhs, rhs in
                guard let lhsMean = lhs.summary.mean else { return false }
                guard let rhsMean = rhs.summary.mean else { return true }

                switch metric.direction {
                case .lowerIsBetter:
                    if lhsMean != rhsMean { return lhsMean < rhsMean }
                case .higherIsBetter:
                    if lhsMean != rhsMean { return lhsMean > rhsMean }
                case .neutral:
                    if lhs.run.startedAt != rhs.run.startedAt { return lhs.run.startedAt > rhs.run.startedAt }
                }

                return lhs.run.startedAt > rhs.run.startedAt
            }
            .first
    }

    private func trend(
        from summaries: [BenchmarkComparableRunMetricSummary],
        metric: BenchmarkMetric
    ) -> BenchmarkTrendSummary {
        guard summaries.count >= 2,
              let first = summaries.first,
              let latest = summaries.last
        else {
            return .unavailable(sampleCount: summaries.reduce(0) { $0 + $1.summary.count })
        }

        return trend(from: first, to: latest, metric: metric)
    }

    private func trend(
        from baseline: BenchmarkComparableRunMetricSummary?,
        to current: BenchmarkComparableRunMetricSummary,
        metric: BenchmarkMetric
    ) -> BenchmarkTrendSummary {
        guard let baseline,
              let baselineMean = baseline.summary.mean,
              let currentMean = current.summary.mean
        else {
            return .unavailable(sampleCount: (baseline?.summary.count ?? 0) + current.summary.count)
        }

        let delta = BenchmarkDelta(baseline: baselineMean, current: currentMean)
        return BenchmarkTrendSummary(
            direction: direction(for: delta, metric: metric),
            delta: delta,
            sampleCount: baseline.summary.count + current.summary.count
        )
    }

    private func historyOutcomes(
        previousComparableTrend: BenchmarkTrendSummary,
        lastRuns: [BenchmarkComparableRunMetricSummary],
        metric: BenchmarkMetric
    ) -> Set<BenchmarkTrendHistoryOutcome> {
        var outcomes: Set<BenchmarkTrendHistoryOutcome> = []

        if lastRuns.count < policy.lastRunCount {
            outcomes.insert(.sparseHistory)
        }

        if previousComparableTrend.direction == .unchanged {
            outcomes.insert(.suppressedSmallMovement)
        }

        let adjacentDirections = zip(lastRuns, lastRuns.dropFirst()).map { previous, current in
            trend(from: previous, to: current, metric: metric).direction
        }
        let meaningfulDirections = adjacentDirections.filter { direction in
            direction == .improved || direction == .regressed
        }
        if meaningfulDirections.contains(.improved) && meaningfulDirections.contains(.regressed) {
            outcomes.insert(.noisyHistory)
        }

        return outcomes
    }

    private func classification(
        previousComparableTrend: BenchmarkTrendSummary,
        lastRunTrend: BenchmarkTrendSummary,
        lastRuns: [BenchmarkComparableRunMetricSummary],
        outcomes: Set<BenchmarkTrendHistoryOutcome>,
        metric: BenchmarkMetric
    ) -> BenchmarkTrendClassification {
        guard previousComparableTrend.direction != .unavailable else {
            return .missingBaseline
        }

        if outcomes.contains(.noisyHistory) {
            if recovered(lastRuns: lastRuns, metric: metric) {
                return .recovered
            }
            return .volatile
        }

        switch lastRunTrend.direction {
        case .improved:
            return .improving
        case .regressed:
            return .regressing
        case .unchanged, .unavailable:
            return .stable
        }
    }

    private func recovered(
        lastRuns: [BenchmarkComparableRunMetricSummary],
        metric: BenchmarkMetric
    ) -> Bool {
        guard lastRuns.count >= 3,
              let current = lastRuns.last,
              let previous = lastRuns.dropLast().last,
              let bestOlder = bestSummary(in: Array(lastRuns.dropLast(1)), metric: metric),
              let currentMean = current.summary.mean,
              let previousMean = previous.summary.mean,
              let bestOlderMean = bestOlder.summary.mean
        else {
            return false
        }

        let previousToCurrent = direction(
            for: BenchmarkDelta(baseline: previousMean, current: currentMean),
            metric: metric
        )
        let bestToPrevious = direction(
            for: BenchmarkDelta(baseline: bestOlderMean, current: previousMean),
            metric: metric
        )

        return previousToCurrent == .improved && bestToPrevious == .regressed
    }

    private func confidence(
        classification: BenchmarkTrendClassification,
        lastRuns: [BenchmarkComparableRunMetricSummary],
        outcomes: Set<BenchmarkTrendHistoryOutcome>
    ) -> BenchmarkTrendConfidence {
        if classification == .missingBaseline {
            return .unavailable
        }

        if lastRuns.count >= policy.minimumRunsForHighConfidence && !outcomes.contains(.noisyHistory) {
            return .high
        }

        if outcomes.contains(.sparseHistory) {
            return .low
        }

        return .medium
    }

    private func direction(for delta: BenchmarkDelta, metric: BenchmarkMetric) -> BenchmarkTrendDirection {
        if !isMeaningful(delta) {
            return .unchanged
        }

        switch metric.direction {
        case .lowerIsBetter:
            return delta.absolute < 0 ? .improved : .regressed
        case .higherIsBetter:
            return delta.absolute > 0 ? .improved : .regressed
        case .neutral:
            return .unchanged
        }
    }

    private func isMeaningful(_ delta: BenchmarkDelta) -> Bool {
        let passesDelta = abs(delta.absolute) >= policy.minimumAbsoluteDelta
        let passesPercentage = delta.percentage.map { abs($0) >= policy.minimumAbsolutePercentageChange } ??
            (policy.minimumAbsolutePercentageChange == 0)
        return passesDelta && passesPercentage
    }
}

private extension [BenchmarkComparableRunMetricSummary] {
    func sortedByBenchmarkStartedAtAscending() -> [BenchmarkComparableRunMetricSummary] {
        sorted { lhs, rhs in
            if lhs.run.startedAt == rhs.run.startedAt {
                return lhs.run.id.rawValue < rhs.run.id.rawValue
            }

            return lhs.run.startedAt < rhs.run.startedAt
        }
    }

    func sortedByBenchmarkStartedAtDescending() -> [BenchmarkComparableRunMetricSummary] {
        sorted { lhs, rhs in
            if lhs.run.startedAt == rhs.run.startedAt {
                return lhs.run.id.rawValue < rhs.run.id.rawValue
            }

            return lhs.run.startedAt > rhs.run.startedAt
        }
    }
}

/// The benchmark facet that connected a performance change note to a comparison.
public enum BenchmarkRelatedPerformanceChangeNoteScope: String, Hashable, Codable, Sendable {
    /// The note matched the compared metric identifier.
    case metric

    /// The note matched the compared scenario identifier.
    case scenario

    /// The note matched the compared suite identifier.
    case suite

    /// The note matched the comparable scenario fingerprint.
    case scenarioFingerprint

    /// The note matched the workflow family in the scenario fingerprint.
    case workflowFamily

    /// The note matched a caller-supplied dashboard history scope.
    case historyScope
}

/// A performance change note related to a benchmark comparison.
public struct BenchmarkRelatedPerformanceChangeNote: Hashable, Codable, Sendable {
    /// The matched performance change note.
    public var note: BenchmarkPerformanceChangeNote

    /// The note reference that matched the comparison target.
    public var affectedBenchmark: BenchmarkPerformanceChangeAffectedBenchmark

    /// The facets that connected the note to the comparison target.
    public var matchedScopes: Set<BenchmarkRelatedPerformanceChangeNoteScope>

    /// Difference between the compared build and note build, when both are numeric.
    public var buildDistance: Int?

    /// Creates a related performance change note result.
    public init(
        note: BenchmarkPerformanceChangeNote,
        affectedBenchmark: BenchmarkPerformanceChangeAffectedBenchmark,
        matchedScopes: Set<BenchmarkRelatedPerformanceChangeNoteScope>,
        buildDistance: Int? = nil
    ) {
        self.note = note
        self.affectedBenchmark = affectedBenchmark
        self.matchedScopes = matchedScopes
        self.buildDistance = buildDistance
    }
}

/// A baseline-current comparison for one benchmark metric.
public struct BenchmarkComparison: Hashable, Codable, Sendable {
    /// The metric being compared.
    public var metric: BenchmarkMetric

    /// Summary statistics for baseline samples.
    public var baseline: BenchmarkSampleSummary

    /// Summary statistics for current samples.
    public var current: BenchmarkSampleSummary

    /// Whether the comparison has complete or missing data.
    public var dataState: BenchmarkComparisonDataState

    /// The baseline-current delta when both sides have data.
    public var delta: BenchmarkDelta?

    /// The interpreted benchmark movement.
    public var trend: BenchmarkTrendSummary

    /// Performance change notes related to the compared benchmark and build window.
    public var relatedPerformanceChangeNotes: [BenchmarkRelatedPerformanceChangeNote]

    /// Creates a benchmark comparison.
    public init(
        metric: BenchmarkMetric,
        baseline: BenchmarkSampleSummary,
        current: BenchmarkSampleSummary,
        dataState: BenchmarkComparisonDataState,
        delta: BenchmarkDelta?,
        trend: BenchmarkTrendSummary,
        relatedPerformanceChangeNotes: [BenchmarkRelatedPerformanceChangeNote] = []
    ) {
        self.metric = metric
        self.baseline = baseline
        self.current = current
        self.dataState = dataState
        self.delta = delta
        self.trend = trend
        self.relatedPerformanceChangeNotes = relatedPerformanceChangeNotes
    }

    private enum CodingKeys: String, CodingKey {
        case metric
        case baseline
        case current
        case dataState
        case delta
        case trend
        case relatedPerformanceChangeNotes
    }

    /// Decodes a comparison while preserving compatibility with payloads captured before related notes.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metric = try container.decode(BenchmarkMetric.self, forKey: .metric)
        baseline = try container.decode(BenchmarkSampleSummary.self, forKey: .baseline)
        current = try container.decode(BenchmarkSampleSummary.self, forKey: .current)
        dataState = try container.decode(BenchmarkComparisonDataState.self, forKey: .dataState)
        delta = try container.decodeIfPresent(BenchmarkDelta.self, forKey: .delta)
        trend = try container.decode(BenchmarkTrendSummary.self, forKey: .trend)
        relatedPerformanceChangeNotes = try container.decodeIfPresent(
            [BenchmarkRelatedPerformanceChangeNote].self,
            forKey: .relatedPerformanceChangeNotes
        ) ?? []
    }

    /// Encodes a comparison, including related performance change notes.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(metric, forKey: .metric)
        try container.encode(baseline, forKey: .baseline)
        try container.encode(current, forKey: .current)
        try container.encode(dataState, forKey: .dataState)
        try container.encodeIfPresent(delta, forKey: .delta)
        try container.encode(trend, forKey: .trend)
        try container.encode(relatedPerformanceChangeNotes, forKey: .relatedPerformanceChangeNotes)
    }
}

/// The type of visible benchmark insight produced from a comparison.
public enum BenchmarkInsightKind: String, Hashable, Codable, Sendable {
    /// The current value moved in the metric's worse direction.
    case regression

    /// The current value moved in the metric's better direction.
    case improvement

    /// The display title for the insight kind.
    public var title: String {
        switch self {
        case .regression:
            "Regression"
        case .improvement:
            "Improvement"
        }
    }
}

/// A single visible insight about a benchmark comparison.
public struct BenchmarkComparisonInsight: Hashable, Codable, Sendable {
    /// The insight category.
    public var kind: BenchmarkInsightKind

    /// The comparison that produced the insight.
    public var comparison: BenchmarkComparison

    /// A concise, non-causal title for display.
    public var title: String

    /// A non-causal summary of the current value relative to the baseline.
    public var summary: String

    /// Creates a benchmark comparison insight.
    public init(
        kind: BenchmarkInsightKind,
        comparison: BenchmarkComparison,
        title: String,
        summary: String
    ) {
        self.kind = kind
        self.comparison = comparison
        self.title = title
        self.summary = summary
    }
}

/// Conservative policy used to decide whether a comparison deserves a visible insight.
public struct BenchmarkInsightEvaluationPolicy: Hashable, Codable, Sendable {
    /// The minimum number of baseline and current samples required.
    public var minimumSamplesPerSide: Int

    /// The minimum absolute percentage movement required.
    public var minimumAbsolutePercentageChange: Double

    /// The minimum absolute raw-value movement required.
    public var minimumAbsoluteDelta: Double

    /// Whether improvements may be emitted as visible insights.
    public var includesImprovements: Bool

    /// Whether regressions may be emitted as visible insights.
    public var includesRegressions: Bool

    /// Creates an insight evaluation policy.
    public init(
        minimumSamplesPerSide: Int = 2,
        minimumAbsolutePercentageChange: Double = 10,
        minimumAbsoluteDelta: Double = 0,
        includesImprovements: Bool = true,
        includesRegressions: Bool = true
    ) {
        self.minimumSamplesPerSide = max(0, minimumSamplesPerSide)
        self.minimumAbsolutePercentageChange = max(0, minimumAbsolutePercentageChange)
        self.minimumAbsoluteDelta = max(0, minimumAbsoluteDelta)
        self.includesImprovements = includesImprovements
        self.includesRegressions = includesRegressions
    }

    /// The default policy for post-run benchmark insights.
    public static let `default` = Self()
}

/// Evaluates benchmark comparisons and emits at most one visible, non-causal insight.
public struct BenchmarkInsightEvaluator: Sendable {
    /// The threshold and inclusion policy used by the evaluator.
    public var policy: BenchmarkInsightEvaluationPolicy

    /// Creates an insight evaluator.
    public init(policy: BenchmarkInsightEvaluationPolicy = .default) {
        self.policy = policy
    }

    /// Returns the strongest visible insight for a collection of comparisons, when one is warranted.
    public func visibleInsight(for comparisons: [BenchmarkComparison]) -> BenchmarkComparisonInsight? {
        comparisons
            .compactMap(makeInsight)
            .sorted(by: insightSort)
            .first
    }

    /// Returns zero insights or the single strongest visible insight for a collection of comparisons.
    public func visibleInsights(for comparisons: [BenchmarkComparison]) -> [BenchmarkComparisonInsight] {
        visibleInsight(for: comparisons).map { [$0] } ?? []
    }

    /// Returns a visible insight for one comparison, when one is warranted.
    public func visibleInsight(for comparison: BenchmarkComparison) -> BenchmarkComparisonInsight? {
        makeInsight(from: comparison)
    }

    private func makeInsight(from comparison: BenchmarkComparison) -> BenchmarkComparisonInsight? {
        guard comparison.dataState == .complete,
              comparison.baseline.count >= policy.minimumSamplesPerSide,
              comparison.current.count >= policy.minimumSamplesPerSide,
              let delta = comparison.delta,
              let percentage = delta.percentage,
              abs(percentage) >= policy.minimumAbsolutePercentageChange,
              abs(delta.absolute) >= policy.minimumAbsoluteDelta
        else {
            return nil
        }

        let kind: BenchmarkInsightKind
        switch comparison.trend.direction {
        case .regressed where policy.includesRegressions:
            kind = .regression
        case .improved where policy.includesImprovements:
            kind = .improvement
        case .improved, .regressed, .unchanged, .unavailable:
            return nil
        }

        return BenchmarkComparisonInsight(
            kind: kind,
            comparison: comparison,
            title: "\(comparison.metric.name) \(kind.title.lowercased()) versus baseline",
            summary: summary(for: comparison, delta: delta, percentage: percentage)
        )
    }

    private func insightSort(_ lhs: BenchmarkComparisonInsight, _ rhs: BenchmarkComparisonInsight) -> Bool {
        if lhs.kind != rhs.kind {
            return lhs.kind == .regression
        }

        let lhsPercentage = abs(lhs.comparison.delta?.percentage ?? 0)
        let rhsPercentage = abs(rhs.comparison.delta?.percentage ?? 0)
        if lhsPercentage != rhsPercentage {
            return lhsPercentage > rhsPercentage
        }

        if lhs.comparison.trend.sampleCount != rhs.comparison.trend.sampleCount {
            return lhs.comparison.trend.sampleCount > rhs.comparison.trend.sampleCount
        }

        return lhs.comparison.metric.name.localizedStandardCompare(rhs.comparison.metric.name) == .orderedAscending
    }

    private func summary(
        for comparison: BenchmarkComparison,
        delta: BenchmarkDelta,
        percentage: Double
    ) -> String {
        let baseline = BenchmarkValueFormatter.value(comparison.baseline.mean, unit: comparison.metric.unit)
        let current = BenchmarkValueFormatter.value(comparison.current.mean, unit: comparison.metric.unit)
        let percent = unsignedPercent(abs(percentage))
        let movement = delta.absolute < 0 ? "lower" : "higher"

        return "\(comparison.metric.name) is \(percent) \(movement) than the comparable baseline (\(baseline) to \(current)). Review the benchmark details before drawing conclusions."
    }

    private func unsignedPercent(_ percentage: Double) -> String {
        let formatted = BenchmarkValueFormatter.percent(percentage)
        return formatted.hasPrefix("+") ? String(formatted.dropFirst()) : formatted
    }
}

/// Builds comparisons and trend summaries for one benchmark metric.
public struct BenchmarkComparisonBuilder: Sendable {
    /// The metric that controls filtering and trend direction.
    public var metric: BenchmarkMetric

    /// The absolute delta tolerance treated as unchanged.
    public var unchangedTolerance: Double

    /// Creates a comparison builder.
    public init(metric: BenchmarkMetric, unchangedTolerance: Double = 0) {
        self.metric = metric
        self.unchangedTolerance = unchangedTolerance
    }

    /// Creates a baseline-current comparison from samples.
    public func makeComparison(
        baseline baselineSamples: [BenchmarkSample],
        current currentSamples: [BenchmarkSample],
        relatedPerformanceChangeNotes: [BenchmarkRelatedPerformanceChangeNote] = []
    ) -> BenchmarkComparison {
        let baseline = BenchmarkSampleSummary(samples: samplesMatchingMetric(in: baselineSamples))
        let current = BenchmarkSampleSummary(samples: samplesMatchingMetric(in: currentSamples))
        let dataState = makeDataState(baselineCount: baseline.count, currentCount: current.count)

        guard let baselineMean = baseline.mean, let currentMean = current.mean else {
            return BenchmarkComparison(
                metric: metric,
                baseline: baseline,
                current: current,
                dataState: dataState,
                delta: nil,
                trend: .unavailable(sampleCount: baseline.count + current.count),
                relatedPerformanceChangeNotes: relatedPerformanceChangeNotes
            )
        }

        let delta = BenchmarkDelta(baseline: baselineMean, current: currentMean)
        let trend = BenchmarkTrendSummary(
            direction: direction(for: delta),
            delta: delta,
            sampleCount: baseline.count + current.count
        )

        return BenchmarkComparison(
            metric: metric,
            baseline: baseline,
            current: current,
            dataState: dataState,
            delta: delta,
            trend: trend,
            relatedPerformanceChangeNotes: relatedPerformanceChangeNotes
        )
    }

    /// Creates a trend summary from the first and latest samples.
    public func makeTrendSummary(from samples: [BenchmarkSample]) -> BenchmarkTrendSummary {
        let matchingSamples = samplesMatchingMetric(in: samples)
            .sorted { $0.measuredAt < $1.measuredAt }

        guard
            matchingSamples.count >= 2,
            let first = matchingSamples.first,
            let latest = matchingSamples.last
        else {
            return .unavailable(sampleCount: matchingSamples.count)
        }

        let delta = BenchmarkDelta(baseline: first.value, current: latest.value)
        return BenchmarkTrendSummary(
            direction: direction(for: delta),
            delta: delta,
            sampleCount: matchingSamples.count
        )
    }

    private func samplesMatchingMetric(in samples: [BenchmarkSample]) -> [BenchmarkSample] {
        samples.filter { $0.metricID == metric.id }
    }

    private func makeDataState(baselineCount: Int, currentCount: Int) -> BenchmarkComparisonDataState {
        switch (baselineCount == 0, currentCount == 0) {
        case (false, false):
            .complete
        case (true, false):
            .missingBaseline
        case (false, true):
            .missingCurrent
        case (true, true):
            .missingBaselineAndCurrent
        }
    }

    private func direction(for delta: BenchmarkDelta) -> BenchmarkTrendDirection {
        guard abs(delta.absolute) > unchangedTolerance else {
            return .unchanged
        }

        switch metric.direction {
        case .lowerIsBetter:
            return delta.absolute < 0 ? .improved : .regressed
        case .higherIsBetter:
            return delta.absolute > 0 ? .improved : .regressed
        case .neutral:
            return .unchanged
        }
    }
}
