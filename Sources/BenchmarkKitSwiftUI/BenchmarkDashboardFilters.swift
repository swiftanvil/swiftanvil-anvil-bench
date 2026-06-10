import BenchmarkKit
import Foundation

/// Archive history modes supported by the dashboard.
public enum BenchmarkDashboardArchiveSelection: String, CaseIterable, Hashable, Sendable {
    /// Show active history only.
    case active

    /// Show archived history only.
    case archived

    /// Show active and archived history.
    case all

    /// The display title for the archive mode.
    public var title: String {
        switch self {
        case .active:
            "Active"
        case .archived:
            "Archived"
        case .all:
            "All"
        }
    }

    var queryFilter: BenchmarkArchiveFilter {
        switch self {
        case .active:
            .active
        case .archived:
            .archived
        case .all:
            .all
        }
    }
}

/// Comparison states that can be selected independently from run archive filters.
public enum BenchmarkDashboardStatusFilter: String, CaseIterable, Hashable, Sendable {
    /// Show all comparison states.
    case all

    /// Show regressions.
    case regressed

    /// Show improvements.
    case improved

    /// Show unchanged comparisons.
    case unchanged

    /// Show missing baseline or current data.
    case missingData

    /// Show unavailable trend rows.
    case unavailable

    /// The display title for the status filter.
    public var title: String {
        switch self {
        case .all:
            "All States"
        case .regressed:
            "Regressed"
        case .improved:
            "Improved"
        case .unchanged:
            "Unchanged"
        case .missingData:
            "Missing Data"
        case .unavailable:
            "Unavailable"
        }
    }

    func accepts(_ status: BenchmarkComparisonStatus) -> Bool {
        switch self {
        case .all:
            true
        case .regressed:
            status == .regressed
        case .improved:
            status == .improved
        case .unchanged:
            status == .unchanged
        case .missingData:
            status.isMissingData
        case .unavailable:
            status == .unavailable
        }
    }
}

/// Date windows supported by the dashboard shell.
public enum BenchmarkDashboardDateFilter: String, CaseIterable, Hashable, Sendable {
    /// Show all dates.
    case all

    /// Show measurements from the last seven days.
    case last7Days

    /// Show measurements from the last thirty days.
    case last30Days

    /// The display title for the date filter.
    public var title: String {
        switch self {
        case .all:
            "All Dates"
        case .last7Days:
            "Last 7 Days"
        case .last30Days:
            "Last 30 Days"
        }
    }

    func dateRange(relativeTo referenceDate: Date) -> BenchmarkDateRange? {
        switch self {
        case .all:
            nil
        case .last7Days:
            BenchmarkDateRange(from: referenceDate.addingTimeInterval(-7 * 24 * 60 * 60), through: referenceDate)
        case .last30Days:
            BenchmarkDateRange(from: referenceDate.addingTimeInterval(-30 * 24 * 60 * 60), through: referenceDate)
        }
    }
}

struct BenchmarkDashboardFilterState: Hashable {
    var archiveSelection: BenchmarkDashboardArchiveSelection
    var selectedSuiteID: BenchmarkSuite.ID?
    var selectedScenarioID: BenchmarkScenario.ID?
    var selectedMetricID: BenchmarkMetric.ID?
    var selectedTagIDs: Set<BenchmarkTag.ID>
    var selectedComparisonDimensionValues: [BenchmarkComparisonDimension.ID: BenchmarkComparisonDimensionValue]
    var dateFilter: BenchmarkDashboardDateFilter
    var statusFilter: BenchmarkDashboardStatusFilter
    /// Active cohort for the persistent filter bar. `nil` means "all cohorts".
    var activeCohortID: BenchmarkCohort.ID?
    /// Cohort "A" in the comparison-cohort picker. Drives the left-hand column on the Comparison screen.
    var comparisonCohortAID: BenchmarkCohort.ID?
    /// Cohort "B" in the comparison-cohort picker. Drives the right-hand column on the Comparison screen.
    var comparisonCohortBID: BenchmarkCohort.ID?

    init(initialArchiveFilter: BenchmarkArchiveFilter = .active) {
        archiveSelection = switch initialArchiveFilter {
        case .active:
            .active
        case .archived:
            .archived
        case .all, .states:
            .all
        }
        selectedSuiteID = nil
        selectedScenarioID = nil
        selectedMetricID = nil
        selectedTagIDs = []
        selectedComparisonDimensionValues = [:]
        dateFilter = .all
        statusFilter = .all
        activeCohortID = nil
        comparisonCohortAID = nil
        comparisonCohortBID = nil
    }

    init(archiveSelection: BenchmarkDashboardArchiveSelection = .active) {
        self.init(initialArchiveFilter: archiveSelection.queryFilter)
    }

    mutating func reset(initialArchiveFilter: BenchmarkArchiveFilter = .active) {
        self = BenchmarkDashboardFilterState(initialArchiveFilter: initialArchiveFilter)
    }

    mutating func reset(archiveSelection: BenchmarkDashboardArchiveSelection = .active) {
        reset(initialArchiveFilter: archiveSelection.queryFilter)
    }
}
