import BenchmarkKit

struct BenchmarkDashboardInsightRunSummary: Identifiable, Hashable {
    var id: BenchmarkRun.ID {
        run.id
    }

    var run: BenchmarkRun
    var summary: BenchmarkSampleSummary
}

struct BenchmarkDashboardInsightCard: Identifiable, Hashable {
    struct ID: Hashable {
        var suiteID: BenchmarkSuite.ID
        var scenarioID: BenchmarkScenario.ID
        var metricID: BenchmarkMetric.ID
        var currentRunID: BenchmarkRun.ID
    }

    var id: ID {
        ID(
            suiteID: suite.id,
            scenarioID: scenario.id,
            metricID: metric.id,
            currentRunID: current.id
        )
    }

    var suite: BenchmarkSuite
    var scenario: BenchmarkScenario
    var metric: BenchmarkMetric
    var current: BenchmarkDashboardInsightRunSummary
    var previousComparable: BenchmarkDashboardInsightRunSummary?
    var bestRecent: BenchmarkDashboardInsightRunSummary?
    var lastRuns: [BenchmarkDashboardInsightRunSummary]
    var lastRunTrend: BenchmarkTrendSummary
    var previousComparableTrend: BenchmarkTrendSummary
    var bestRecentTrend: BenchmarkTrendSummary
    var classification: BenchmarkTrendClassification
    var confidence: BenchmarkTrendConfidence
    var fingerprintSummary: String?
    var outcomeSummaries: [String]

    init(
        suite: BenchmarkSuite,
        scenario: BenchmarkScenario,
        metric: BenchmarkMetric,
        evaluation: BenchmarkTrendEvaluation,
        fingerprintSummary: String? = nil
    ) {
        self.suite = suite
        self.scenario = scenario
        self.metric = metric
        current = BenchmarkDashboardInsightRunSummary(evaluation.current)
        previousComparable = evaluation.previousComparable.map(BenchmarkDashboardInsightRunSummary.init)
        bestRecent = evaluation.bestRecent.map(BenchmarkDashboardInsightRunSummary.init)
        lastRuns = evaluation.lastRuns.map(BenchmarkDashboardInsightRunSummary.init)
        lastRunTrend = evaluation.lastRunTrend
        previousComparableTrend = evaluation.previousComparableTrend
        bestRecentTrend = evaluation.bestRecentTrend
        classification = evaluation.classification
        confidence = evaluation.confidence
        self.fingerprintSummary = fingerprintSummary ?? Self.fingerprintSummary(for: evaluation.current.run)
        outcomeSummaries = evaluation.outcomes
            .map(\.summary)
            .sorted()
    }

    init(
        suite: BenchmarkSuite,
        scenario: BenchmarkScenario,
        metric: BenchmarkMetric,
        current: BenchmarkDashboardInsightRunSummary,
        previousComparable: BenchmarkDashboardInsightRunSummary?,
        bestRecent: BenchmarkDashboardInsightRunSummary?,
        lastRuns: [BenchmarkDashboardInsightRunSummary],
        lastRunTrend: BenchmarkTrendSummary,
        previousComparableTrend: BenchmarkTrendSummary,
        bestRecentTrend: BenchmarkTrendSummary,
        classification: BenchmarkTrendClassification,
        confidence: BenchmarkTrendConfidence,
        fingerprintSummary: String?,
        outcomeSummaries: [String] = []
    ) {
        self.suite = suite
        self.scenario = scenario
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
        self.fingerprintSummary = fingerprintSummary
        self.outcomeSummaries = outcomeSummaries
    }

    private static func fingerprintSummary(for run: BenchmarkRun) -> String? {
        if let scenarioFingerprint = run.scenarioFingerprint {
            return scenarioFingerprint.stableSortValue
        }

        if let titleHash = run.titleHash, !titleHash.isEmpty {
            return "Title hash \(titleHash)"
        }

        return nil
    }
}

private extension BenchmarkDashboardInsightRunSummary {
    init(_ comparableSummary: BenchmarkComparableRunMetricSummary) {
        run = comparableSummary.run
        summary = comparableSummary.summary
    }
}

private extension BenchmarkScenarioFingerprint {
    var stableSortValue: String {
        let strictParts = strictGates.values.map { "\($0.dimension.rawValue): \($0.value)" }
        let fuzzyParts = fuzzyBucket.values.map { "\($0.dimension.rawValue): \($0.value)" }
        return (strictParts + fuzzyParts)
            .joined(separator: " | ")
    }
}

private extension BenchmarkTrendHistoryOutcome {
    var summary: String {
        switch self {
        case .sparseHistory:
            "Sparse history"
        case .noisyHistory:
            "Noisy history"
        case .suppressedSmallMovement:
            "Small movement suppressed"
        }
    }
}
