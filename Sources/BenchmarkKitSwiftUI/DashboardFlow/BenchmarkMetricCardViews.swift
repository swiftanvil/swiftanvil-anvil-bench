import BenchmarkKit
import SwiftUI

struct BenchmarkScenarioSelectionCard: View {
    let scenarioGroup: BenchmarkScenarioGroup
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(scenarioGroup.scenario.name)
                .font(.headline)
                .multilineTextAlignment(.leading)

            if let latest = scenarioGroup.summary.latestRunStartedAt {
                Label(BenchmarkValueFormatter.date(latest), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            BenchmarkCompactSummaryRow(summary: scenarioGroup.summary)
        }
        .frame(width: 250, alignment: .leading)
        .frame(minHeight: 148, alignment: .leading)
        .padding(16)
        .background(
            isSelected ? Color.accentColor.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: isSelected ? 1.5 : 1)
        }
    }
}

struct BenchmarkMetricCarouselCard: View {
    let row: BenchmarkComparisonRow
    var title: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title ?? row.metric.name)
                        .font(.headline)
                    Text(BenchmarkValueFormatter.value(row.comparison.current.mean, unit: row.metric.unit))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 8)
                BenchmarkStatusBadge(status: row.status)
            }

            BenchmarkMetricSparkline(row: row)

            HStack {
                BenchmarkValueField(
                    title: "Delta",
                    value: BenchmarkValueFormatter.delta(row.comparison.delta, unit: row.metric.unit)
                )
                BenchmarkValueField(title: "Samples", value: "\(row.comparison.current.count)")
            }
        }
        .frame(width: 320, alignment: .leading)
        .frame(minHeight: 220, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.quaternary)
        }
    }
}

struct BenchmarkMetricHeroCard: View {
    let row: BenchmarkComparisonRow
    var title: String?
    var subtitle: String?
    var showsContextSubtitle = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title ?? row.metric.name)
                        .font(.title3.weight(.semibold))
                    if let resolvedSubtitle, showsContextSubtitle {
                        Text(resolvedSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)
                BenchmarkStatusBadge(status: row.status)
            }

            HStack(spacing: 10) {
                BenchmarkHeroValueTile(
                    title: "Baseline",
                    value: BenchmarkValueFormatter.value(row.comparison.baseline.mean, unit: row.metric.unit)
                )
                BenchmarkHeroValueTile(
                    title: "Current",
                    value: BenchmarkValueFormatter.value(row.comparison.current.mean, unit: row.metric.unit)
                )
                BenchmarkHeroValueTile(
                    title: "Delta",
                    value: BenchmarkValueFormatter.delta(row.comparison.delta, unit: row.metric.unit)
                )
            }

            BenchmarkMetricSparkline(row: row, fixedHeight: 180)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var resolvedSubtitle: String? {
        if let subtitle {
            return subtitle
        }

        return "\(row.suite.name) / \(row.scenario.name)"
    }
}

struct BenchmarkHeroValueTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BenchmarkMetricSelectionPill: View {
    let title: String
    let value: String
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            if isSelected {
                Capsule().fill(Color.accentColor.opacity(0.14))
            } else {
                Capsule().fill(.thinMaterial)
            }
        }
        .overlay {
            Capsule()
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
        }
    }
}
