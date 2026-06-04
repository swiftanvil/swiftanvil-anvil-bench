import BenchmarkKit

enum BenchmarkDashboardReachabilityRoute: String, Hashable {
    case auditMatrix
    case sampleIndex
    case exportCenter
    case debugControls

    var title: String {
        switch self {
        case .auditMatrix:
            "Audit Matrix"
        case .sampleIndex:
            "Sample Index"
        case .exportCenter:
            "Export Center"
        case .debugControls:
            "Debug Controls"
        }
    }
}

struct BenchmarkSuiteRoute: Hashable {
    var suiteID: BenchmarkSuite.ID
}

struct BenchmarkScenarioRoute: Hashable {
    var suite: BenchmarkSuite
    var scenario: BenchmarkScenario
    var metricID: BenchmarkMetric.ID?
}

struct BenchmarkScenarioDetailIdentity: Hashable {
    var scenarioID: BenchmarkScenario.ID
    var selectedComparisonDimensionValues: [BenchmarkComparisonDimension.ID: BenchmarkComparisonDimensionValue]
}
