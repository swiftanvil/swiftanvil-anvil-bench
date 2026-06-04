import BenchmarkKit
import Foundation

enum BenchmarkDashboardMode: String, CaseIterable, Hashable, Sendable {
    case summary
    case suites

    static let defaultMode: Self = .summary

    var title: String {
        switch self {
        case .summary:
            "Summary"
        case .suites:
            "Suites"
        }
    }
}

struct BenchmarkDashboardDefaultState: Hashable, Sendable {
    static let topComparisonLimit = 3

    var mode: BenchmarkDashboardMode
    var topRegressions: [BenchmarkComparisonRow]
    var topImprovements: [BenchmarkComparisonRow]
    var currentBaseline: BenchmarkComparisonRow?
    var primaryTrend: BenchmarkComparisonRow?

    init(
        rows: [BenchmarkComparisonRow],
        mode: BenchmarkDashboardMode = .defaultMode,
        topComparisonLimit: Int = Self.topComparisonLimit
    ) {
        self.mode = mode
        topRegressions = rows
            .filter { $0.status == .regressed }
            .sorted(by: BenchmarkDashboardDefaultState.impactSort)
            .prefix(topComparisonLimit)
            .map(\.self)
        topImprovements = rows
            .filter { $0.status == .improved }
            .sorted(by: BenchmarkDashboardDefaultState.impactSort)
            .prefix(topComparisonLimit)
            .map(\.self)
        currentBaseline = rows
            .filter { $0.comparison.dataState == .complete }
            .sorted(by: BenchmarkDashboardDefaultState.currentBaselineSort)
            .first
        primaryTrend = rows
            .filter { $0.trend.direction != .unavailable && $0.history.sortedPoints.count >= 2 }
            .sorted(by: BenchmarkDashboardDefaultState.primaryTrendSort)
            .first
    }

    private static func impactSort(_ lhs: BenchmarkComparisonRow, _ rhs: BenchmarkComparisonRow) -> Bool {
        let lhsImpact = lhs.deltaImpact
        let rhsImpact = rhs.deltaImpact

        if lhsImpact != rhsImpact {
            return lhsImpact > rhsImpact
        }

        return recencySort(lhs, rhs)
    }

    private static func currentBaselineSort(_ lhs: BenchmarkComparisonRow, _ rhs: BenchmarkComparisonRow) -> Bool {
        if lhs.status.sortRank != rhs.status.sortRank {
            return lhs.status.sortRank < rhs.status.sortRank
        }

        return impactSort(lhs, rhs)
    }

    private static func primaryTrendSort(_ lhs: BenchmarkComparisonRow, _ rhs: BenchmarkComparisonRow) -> Bool {
        if lhs.status == .regressed || rhs.status == .regressed,
           lhs.status != rhs.status {
            return lhs.status == .regressed
        }

        if lhs.trend.sampleCount != rhs.trend.sampleCount {
            return lhs.trend.sampleCount > rhs.trend.sampleCount
        }

        return impactSort(lhs, rhs)
    }

    private static func recencySort(_ lhs: BenchmarkComparisonRow, _ rhs: BenchmarkComparisonRow) -> Bool {
        switch (lhs.latestRunStartedAt, rhs.latestRunStartedAt) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate > rhsDate
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        default:
            return lhs.metric.name.localizedStandardCompare(rhs.metric.name) == .orderedAscending
        }
    }
}

struct BenchmarkOverviewSummary: Hashable, Sendable {
    var totalComparisons: Int
    var regressedCount: Int
    var improvedCount: Int
    var unchangedCount: Int
    var missingDataCount: Int
    var unavailableCount: Int
    var representedSampleCount: Int
    var latestRunStartedAt: Date?
    var archiveSelection: BenchmarkDashboardArchiveSelection
    var insightCards: [BenchmarkDashboardInsightCard]

    init(
        rows: [BenchmarkComparisonRow],
        latestRunStartedAt: Date?,
        archiveSelection: BenchmarkDashboardArchiveSelection,
        insightCards: [BenchmarkDashboardInsightCard]? = nil
    ) {
        totalComparisons = rows.count
        regressedCount = rows.filter { $0.status == .regressed }.count
        improvedCount = rows.filter { $0.status == .improved }.count
        unchangedCount = rows.filter { $0.status == .unchanged }.count
        missingDataCount = rows.filter { $0.status.isMissingData }.count
        unavailableCount = rows.filter { $0.status == .unavailable }.count
        representedSampleCount = rows.reduce(0) { $0 + $1.totalSamples }
        self.latestRunStartedAt = latestRunStartedAt
        self.archiveSelection = archiveSelection
        self.insightCards = insightCards ?? rows.compactMap(\.insightCard)
    }
}

private extension BenchmarkComparisonRow {
    var deltaImpact: Double {
        if let percentage = comparison.delta?.percentage {
            return abs(percentage)
        }

        return abs(comparison.delta?.absolute ?? 0)
    }
}
