import SwiftUI

enum BenchmarkStatusStyle {
    static func color(for status: BenchmarkComparisonStatus) -> Color {
        switch status {
        case .improved:
            .green
        case .regressed:
            .red
        case .unchanged:
            .blue
        case .missingBaseline, .missingCurrent, .missingBaselineAndCurrent:
            .orange
        case .unavailable:
            .secondary
        }
    }
}
