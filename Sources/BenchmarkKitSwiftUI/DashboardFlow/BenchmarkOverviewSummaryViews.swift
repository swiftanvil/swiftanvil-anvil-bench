import BenchmarkKit
import SwiftUI

#if canImport(Charts)
import Charts
#endif

struct BenchmarkOverviewSummarySection: View {
    let summary: BenchmarkOverviewSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BenchmarkOverviewView(summary: summary)

            if !summary.insightCards.isEmpty {
                BenchmarkOverviewInsightSection(insightCards: summary.insightCards)
            }

            BenchmarkOverviewStatusChart(summary: summary)
        }
    }
}

private struct BenchmarkOverviewInsightSection: View {
    let insightCards: [BenchmarkDashboardInsightCard]

    private let columns = [
        GridItem(.adaptive(minimum: 280), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BenchmarkSectionHeader(
                title: "Multi-Build Insights",
                subtitle: "Current build compared with recent matching runs."
            )

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(insightCards) { insightCard in
                    BenchmarkOverviewInsightCard(insightCard: insightCard)
                }
            }
        }
    }
}

private struct BenchmarkOverviewInsightCard: View {
    let insightCard: BenchmarkDashboardInsightCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                BenchmarkInsightValueRow(
                    title: "Current",
                    value: value(for: insightCard.current),
                    detail: BenchmarkValueFormatter.date(insightCard.current.run.startedAt)
                )

                if let previousComparable = insightCard.previousComparable {
                    BenchmarkInsightValueRow(
                        title: "Previous",
                        value: value(for: previousComparable),
                        detail: trendDetail(insightCard.previousComparableTrend)
                    )
                }

                if let bestRecent = insightCard.bestRecent {
                    BenchmarkInsightValueRow(
                        title: "Best Recent",
                        value: value(for: bestRecent),
                        detail: trendDetail(insightCard.bestRecentTrend)
                    )
                }

                BenchmarkInsightValueRow(
                    title: "Last \(insightCard.lastRuns.count)",
                    value: insightCard.lastRunTrend.direction.title,
                    detail: trendDetail(insightCard.lastRunTrend)
                )
            }

            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(tint.opacity(0.24))
        }
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: insightCard.classification.systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(insightCard.metric.name)
                    .font(.headline)
                    .lineLimit(2)

                Text("\(insightCard.suite.name) | \(insightCard.scenario.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(insightCard.classification.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tint.opacity(0.12), in: Capsule())
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(insightCard.confidence.title, systemImage: "checkmark.seal")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let fingerprintSummary = insightCard.fingerprintSummary, !fingerprintSummary.isEmpty {
                Label(fingerprintSummary, systemImage: "fingerprint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !insightCard.outcomeSummaries.isEmpty {
                Text(insightCard.outcomeSummaries.joined(separator: " | "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var tint: Color {
        BenchmarkStatusStyle.color(for: insightCard.classification.status)
    }

    private func value(for runSummary: BenchmarkDashboardInsightRunSummary) -> String {
        BenchmarkValueFormatter.value(runSummary.summary.mean, unit: insightCard.metric.unit)
    }

    private func trendDetail(_ trend: BenchmarkTrendSummary) -> String {
        if let delta = trend.delta {
            return BenchmarkValueFormatter.delta(delta, unit: insightCard.metric.unit)
        }

        return "\(trend.sampleCount) samples"
    }
}

private struct BenchmarkInsightValueRow: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .leading)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()

            Spacer(minLength: 8)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct BenchmarkOverviewStatusChart: View {
    let summary: BenchmarkOverviewSummary

    private var data: [(String, Int, Color)] {
        [
            ("Regressed", summary.regressedCount, BenchmarkStatusStyle.color(for: .regressed)),
            ("Improved", summary.improvedCount, BenchmarkStatusStyle.color(for: .improved)),
            ("Unchanged", summary.unchangedCount, BenchmarkStatusStyle.color(for: .unchanged)),
            ("Missing", summary.missingDataCount, BenchmarkStatusStyle.color(for: .missingBaseline))
        ]
        .filter { $0.1 > 0 }
    }

    var body: some View {
        #if canImport(Charts)
        Chart(data, id: \.0) { label, count, color in
            BarMark(
                x: .value("Count", count),
                y: .value("State", label)
            )
            .foregroundStyle(color)
        }
        .chartXAxisLabel("Comparisons")
        .frame(height: CGFloat(max(140, data.count * 32)))
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.quaternary)
        }
        #else
        BenchmarkChartFallbackView(message: "Overview chart unavailable on this build.")
        #endif
    }
}

struct BenchmarkRecentScenarioCard: View {
    let entry: BenchmarkRecentScenario

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.suite.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(entry.scenario.name)
                .font(.headline)
                .multilineTextAlignment(.leading)

            if let latestRunStartedAt = entry.latestRunStartedAt {
                Label(BenchmarkValueFormatter.date(latestRunStartedAt), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            BenchmarkCompactSummaryRow(summary: entry.summary)
        }
        .frame(width: 250, alignment: .leading)
        .frame(minHeight: 150, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.quaternary)
        }
    }
}

struct BenchmarkSuiteCard: View {
    let group: BenchmarkSuiteGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.suite.name)
                        .font(.headline)
                    Text("\(group.scenarios.count) scenarios")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if let latest = group.summary.latestRunStartedAt {
                    Text(BenchmarkValueFormatter.date(latest))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            BenchmarkCompactSummaryRow(summary: group.summary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.quaternary)
        }
    }
}

private extension BenchmarkTrendClassification {
    var title: String {
        switch self {
        case .improving:
            "Improving"
        case .regressing:
            "Regressing"
        case .stable:
            "Stable"
        case .volatile:
            "Volatile"
        case .recovered:
            "Recovered"
        case .missingBaseline:
            "Missing Baseline"
        }
    }

    var systemImage: String {
        switch self {
        case .improving:
            "arrow.down.right.circle"
        case .regressing:
            "arrow.up.right.circle"
        case .stable:
            "equal.circle"
        case .volatile:
            "waveform.path.ecg"
        case .recovered:
            "arrow.uturn.backward.circle"
        case .missingBaseline:
            "exclamationmark.circle"
        }
    }

    var status: BenchmarkComparisonStatus {
        switch self {
        case .improving, .recovered:
            .improved
        case .regressing, .volatile:
            .regressed
        case .stable:
            .unchanged
        case .missingBaseline:
            .missingBaseline
        }
    }
}

private extension BenchmarkTrendConfidence {
    var title: String {
        switch self {
        case .high:
            "High confidence"
        case .medium:
            "Medium confidence"
        case .low:
            "Low confidence"
        case .unavailable:
            "Confidence unavailable"
        }
    }
}

private extension BenchmarkTrendDirection {
    var title: String {
        switch self {
        case .improved:
            "Improved"
        case .regressed:
            "Regressed"
        case .unchanged:
            "Unchanged"
        case .unavailable:
            "Unavailable"
        }
    }
}
