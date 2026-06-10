import Foundation

/// Consistent value, delta, percentile, and direction formatting for benchmark UIs.
///
/// Lives in `BenchmarkKit` (not the SwiftUI module) so that exporters, tests, and
/// non-SwiftUI surfaces can format values the same way the dashboard does.
public enum BenchmarkValueFormatter {
    private static let bytesPerMegabyte = 1_048_576.0
    private static let millisecondsPerSecond = 1000.0

    /// Formats an optional value with its metric unit.
    public static func value(_ value: Double?, unit: BenchmarkMetricUnit) -> String {
        guard let value else {
            return "Unavailable"
        }

        return formattedValue(value, unit: unit, includeSign: false)
    }

    /// Formats a benchmark delta as absolute + percentage parts.
    public static func delta(_ delta: BenchmarkDelta?, unit: BenchmarkMetricUnit) -> String {
        guard let delta else { return "Unavailable" }
        var parts = [absoluteDelta(delta, unit: unit)]
        if let percentage = delta.percentage {
            parts.append(percent(percentage))
        }
        return parts.joined(separator: " | ")
    }

    /// Formats the absolute portion of a delta.
    public static func absoluteDelta(_ delta: BenchmarkDelta?, unit: BenchmarkMetricUnit) -> String {
        guard let delta else { return "Unavailable" }
        return formattedValue(delta.absolute, unit: unit, includeSign: true)
    }

    /// Formats a percent value with a leading sign.
    public static func percent(_ percentage: Double?) -> String {
        guard let percentage else { return "Unavailable" }
        return "\(signedDecimalNumber(percentage))%"
    }

    /// Formats a date using abbreviated date and shortened time.
    public static func date(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    /// Formats a metric direction.
    public static func direction(_ direction: BenchmarkMetricDirection) -> String {
        switch direction {
        case .lowerIsBetter: "Lower is better"
        case .higherIsBetter: "Higher is better"
        case .neutral: "Neutral"
        }
    }

    /// Formats a trend direction.
    public static func trendDirection(_ direction: BenchmarkTrendDirection) -> String {
        switch direction {
        case .improved: "Improving"
        case .regressed: "Regressing"
        case .unchanged: "Unchanged"
        case .unavailable: "Unavailable"
        }
    }

    /// Formats a percentile label such as `p95` together with its value.
    public static func percentile(_ percentile: Int, value: Double?, unit: BenchmarkMetricUnit) -> String {
        "p\(percentile): \(self.value(value, unit: unit))"
    }

    /// Formats the axis or compact display label for a unit.
    public static func unitLabel(_ unit: BenchmarkMetricUnit) -> String {
        if unit == .bytes {
            return "MB"
        }

        if unit == .milliseconds {
            return "s"
        }

        return unit.rawValue
    }

    /// Converts a stored raw value into the value shown on dashboard charts.
    public static func displayValue(_ value: Double, unit: BenchmarkMetricUnit) -> Double {
        if unit == .bytes {
            return value / bytesPerMegabyte
        }

        if unit == .milliseconds {
            return value / millisecondsPerSecond
        }

        return value
    }

    private static func decimalNumber(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func signedDecimalNumber(_ value: Double) -> String {
        let formatted = decimalNumber(abs(value))
        return value < 0 ? "-\(formatted)" : "+\(formatted)"
    }

    private static func number(_ value: Double, unit: BenchmarkMetricUnit) -> String {
        if unit == .bytes {
            return "\(Int(value.rounded()))"
        }

        return decimalNumber(value)
    }

    private static func signedNumber(_ value: Double, unit: BenchmarkMetricUnit) -> String {
        let formatted = number(abs(value), unit: unit)
        return value < 0 ? "-\(formatted)" : "+\(formatted)"
    }

    private static func formattedValue(
        _ value: Double,
        unit: BenchmarkMetricUnit,
        includeSign: Bool
    ) -> String {
        let displayValue = displayValue(value, unit: unit)
        let value = includeSign ? signedNumber(displayValue, unit: unit) : number(displayValue, unit: unit)
        return "\(value) \(unitLabel(unit))"
    }
}
