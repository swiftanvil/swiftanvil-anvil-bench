import BenchmarkKit
import SwiftUI

struct BenchmarkComparisonListView: View {
    let title: String
    let subtitle: String?
    let rows: [BenchmarkComparisonRow]

    init(
        title: String = "Comparisons",
        subtitle: String? = "Regressions first, then missing data, improvements, and unchanged.",
        rows: [BenchmarkComparisonRow]
    ) {
        self.title = title
        self.subtitle = subtitle
        self.rows = rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BenchmarkSectionHeader(title: title, subtitle: subtitle)

            LazyVStack(spacing: 10) {
                ForEach(rows) { row in
                    NavigationLink(value: row.id) {
                        BenchmarkComparisonRowView(row: row)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct BenchmarkComparisonRowView: View {
    let row: BenchmarkComparisonRow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.metric.name)
                        .font(.headline)
                    Text("\(row.suite.name) / \(row.scenario.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                BenchmarkStatusBadge(status: row.status)
            }

            BenchmarkDeltaHeadline(row: row)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 128), spacing: 10)],
                alignment: .leading,
                spacing: 8
            ) {
                BenchmarkValueField(
                    title: "Baseline",
                    value: BenchmarkValueFormatter.value(row.comparison.baseline.mean, unit: row.metric.unit)
                )
                BenchmarkValueField(
                    title: "Current",
                    value: BenchmarkValueFormatter.value(row.comparison.current.mean, unit: row.metric.unit)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        [
            row.metric.name,
            "\(row.suite.name) \(row.scenario.name)",
            row.status.title,
            "baseline \(BenchmarkValueFormatter.value(row.comparison.baseline.mean, unit: row.metric.unit))",
            "current \(BenchmarkValueFormatter.value(row.comparison.current.mean, unit: row.metric.unit))",
            "absolute delta \(BenchmarkValueFormatter.absoluteDelta(row.comparison.delta, unit: row.metric.unit))",
            "percent delta \(BenchmarkValueFormatter.percent(row.comparison.delta?.percentage))",
        ]
        .compactMap(\.self)
        .joined(separator: ", ")
    }
}

private struct BenchmarkDeltaHeadline: View {
    let row: BenchmarkComparisonRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Delta")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(BenchmarkValueFormatter.absoluteDelta(row.comparison.delta, unit: row.metric.unit))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(BenchmarkStatusStyle.color(for: row.status))
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                Text("Percent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(BenchmarkValueFormatter.percent(row.comparison.delta?.percentage))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(BenchmarkStatusStyle.color(for: row.status))
                    .lineLimit(2)
            }
        }
    }
}
