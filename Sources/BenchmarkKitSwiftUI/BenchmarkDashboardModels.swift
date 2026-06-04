import BenchmarkKit
import Foundation

enum BenchmarkComparisonStatus: Hashable, Sendable {
    case improved
    case regressed
    case unchanged
    case missingBaseline
    case missingCurrent
    case missingBaselineAndCurrent
    case unavailable

    var title: String {
        switch self {
        case .improved:
            "Improved"
        case .regressed:
            "Regressed"
        case .unchanged:
            "Unchanged"
        case .missingBaseline:
            "Missing Baseline"
        case .missingCurrent:
            "Missing Current"
        case .missingBaselineAndCurrent:
            "Missing Baseline And Current"
        case .unavailable:
            "Unavailable"
        }
    }

    var systemImage: String {
        switch self {
        case .improved:
            "arrow.down.right.circle"
        case .regressed:
            "arrow.up.right.circle"
        case .unchanged:
            "equal.circle"
        case .missingBaseline, .missingCurrent, .missingBaselineAndCurrent:
            "exclamationmark.circle"
        case .unavailable:
            "questionmark.circle"
        }
    }

    var isMissingData: Bool {
        switch self {
        case .missingBaseline, .missingCurrent, .missingBaselineAndCurrent:
            true
        case .improved, .regressed, .unchanged, .unavailable:
            false
        }
    }

    var sortRank: Int {
        switch self {
        case .regressed:
            0
        case .missingBaseline, .missingCurrent, .missingBaselineAndCurrent:
            1
        case .improved:
            2
        case .unchanged:
            3
        case .unavailable:
            4
        }
    }
}

enum BenchmarkComparisonScope: String, Hashable, Sendable {
    case baseline
    case current

    var title: String {
        switch self {
        case .baseline:
            "Baseline"
        case .current:
            "Current"
        }
    }
}

struct BenchmarkMetricHistoryPoint: Identifiable, Hashable, Sendable {
    var id: BenchmarkSample.ID
    var scope: BenchmarkComparisonScope
    var value: Double
    var measuredAt: Date
    var runID: BenchmarkRun.ID
    var contextSummary: String?

    func accessibilitySummary(unit: BenchmarkMetricUnit) -> String {
        [
            scope.title,
            BenchmarkValueFormatter.value(value, unit: unit),
            BenchmarkValueFormatter.date(measuredAt),
            contextSummary
        ]
        .compactMap(\.self)
        .joined(separator: ", ")
    }
}

struct BenchmarkMetricHistorySeries: Hashable, Sendable {
    var metric: BenchmarkMetric
    var points: [BenchmarkMetricHistoryPoint]

    var sortedPoints: [BenchmarkMetricHistoryPoint] {
        points.sorted { lhs, rhs in
            if lhs.measuredAt != rhs.measuredAt {
                return lhs.measuredAt < rhs.measuredAt
            }

            return lhs.scope.title < rhs.scope.title
        }
    }
}

struct BenchmarkRunMatrixContext: Identifiable, Hashable, Sendable {
    var id: String {
        "\(scope.rawValue)-\(runID.rawValue)"
    }

    var scope: BenchmarkComparisonScope
    var runID: BenchmarkRun.ID
    var startedAt: Date
    var archiveState: BenchmarkArchiveState
    var metadata: [String: String]
    var summary: String
}

enum BenchmarkComparisonConfidenceLevel: Hashable, Sendable {
    case high
    case medium
    case low
    case unavailable

    var title: String {
        switch self {
        case .high:
            "High Confidence"
        case .medium:
            "Medium Confidence"
        case .low:
            "Low Confidence"
        case .unavailable:
            "Unavailable"
        }
    }
}

struct BenchmarkComparisonConfidence: Hashable, Sendable {
    var level: BenchmarkComparisonConfidenceLevel
    var summary: String
}

struct BenchmarkComparisonRow: Identifiable, Hashable, Sendable {
    struct ID: Hashable, Sendable {
        var suiteID: BenchmarkSuite.ID
        var scenarioID: BenchmarkScenario.ID
        var metricID: BenchmarkMetric.ID
    }

    var id: ID {
        ID(suiteID: suite.id, scenarioID: scenario.id, metricID: metric.id)
    }

    var suite: BenchmarkSuite
    var scenario: BenchmarkScenario
    var metric: BenchmarkMetric
    var comparison: BenchmarkComparison
    var trend: BenchmarkTrendSummary
    var status: BenchmarkComparisonStatus
    var containsArchivedHistory: Bool
    var contextSummary: String?
    var history: BenchmarkMetricHistorySeries
    var matrixContexts: [BenchmarkRunMatrixContext]
    var confidence: BenchmarkComparisonConfidence
    var notes: [String]
    var latestRunStartedAt: Date?
    var insightCard: BenchmarkDashboardInsightCard? = nil

    var totalSamples: Int {
        comparison.baseline.count + comparison.current.count
    }
}

struct BenchmarkScenarioGroup: Identifiable, Hashable, Sendable {
    var id: BenchmarkScenario.ID {
        scenario.id
    }

    var scenario: BenchmarkScenario
    var rows: [BenchmarkComparisonRow]
    var comparisonDimensions: [BenchmarkComparisonDimensionGroup]
    var summary: BenchmarkOverviewSummary
}

struct BenchmarkRecentScenario: Identifiable, Hashable, Sendable {
    var id: String {
        "\(suite.id.rawValue)-\(scenario.id.rawValue)"
    }

    var suite: BenchmarkSuite
    var scenario: BenchmarkScenario
    var rows: [BenchmarkComparisonRow]
    var summary: BenchmarkOverviewSummary
    var latestRunStartedAt: Date?
}

struct BenchmarkSuiteGroup: Identifiable, Hashable, Sendable {
    var id: BenchmarkSuite.ID {
        suite.id
    }

    var suite: BenchmarkSuite
    var scenarios: [BenchmarkScenarioGroup]
    var summary: BenchmarkOverviewSummary
}

struct BenchmarkComparisonDimensionGroup: Identifiable, Hashable, Sendable {
    var id: BenchmarkComparisonDimension.ID {
        dimension.id
    }

    var dimension: BenchmarkComparisonDimension
    var values: [BenchmarkComparisonDimensionValue]
}

struct BenchmarkSelectedComparisonDimensionValue: Identifiable, Hashable, Sendable {
    var id: BenchmarkComparisonDimension.ID {
        dimension.id
    }

    var dimension: BenchmarkComparisonDimension
    var value: BenchmarkComparisonDimensionValue

    var dimensionTitle: String {
        dimension.title
    }

    var title: String
    var subtitle: String?
}

struct BenchmarkDashboardLoadedState: Hashable, Sendable {
    var rows: [BenchmarkComparisonRow]
    var groups: [BenchmarkSuiteGroup]
    var recentScenarios: [BenchmarkRecentScenario]
    var overview: BenchmarkOverviewSummary
    var hasArchivedHistory: Bool
    var isHistoryEmpty: Bool

    var defaultState: BenchmarkDashboardDefaultState {
        BenchmarkDashboardDefaultState(rows: rows)
    }
}

enum BenchmarkDashboardLoadState: Hashable, Sendable {
    case idle
    case loading
    case loaded(BenchmarkDashboardLoadedState)
    case failed(String)
}

struct BenchmarkDashboardLoadKey: Hashable {
    var filters: BenchmarkDashboardFilterState
    var reloadToken: UUID
}
