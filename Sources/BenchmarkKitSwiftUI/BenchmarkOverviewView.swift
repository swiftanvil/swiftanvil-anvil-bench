import BenchmarkKit
import SwiftUI

struct BenchmarkOverviewView: View {
    let summary: BenchmarkOverviewSummary

    private let columns = [
        GridItem(.adaptive(minimum: 168), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BenchmarkSectionHeader(title: "Overview", subtitle: overviewSubtitle)

            BenchmarkOverviewPriorityCard(summary: summary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                BenchmarkOverviewCell(
                    title: "Regressions",
                    value: "\(summary.regressedCount)",
                    detail: "Need triage",
                    systemImage: BenchmarkComparisonStatus.regressed.systemImage,
                    status: .regressed
                )
                BenchmarkOverviewCell(
                    title: "Improvements",
                    value: "\(summary.improvedCount)",
                    detail: "Wins to validate",
                    systemImage: BenchmarkComparisonStatus.improved.systemImage,
                    status: .improved
                )
                BenchmarkOverviewCell(
                    title: "Incomplete",
                    value: "\(summary.incompleteCount)",
                    detail: incompleteDetail,
                    systemImage: BenchmarkComparisonStatus.missingBaseline.systemImage,
                    status: .missingBaseline
                )
                BenchmarkOverviewCell(
                    title: "Covered",
                    value: "\(summary.comparableCount)",
                    detail: "\(summary.totalComparisons) total comparisons",
                    systemImage: "checklist"
                )
                BenchmarkOverviewCell(
                    title: "Samples",
                    value: "\(summary.representedSampleCount)",
                    detail: "Baseline and current",
                    systemImage: "number"
                )
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var overviewSubtitle: String {
        var parts = ["Archive: \(summary.archiveSelection.title)"]

        if let latestRunStartedAt = summary.latestRunStartedAt {
            parts.append("Latest run: \(BenchmarkValueFormatter.date(latestRunStartedAt))")
        }

        return parts.joined(separator: " | ")
    }

    private var incompleteDetail: String {
        if summary.unavailableCount > 0 {
            "\(summary.missingDataCount) missing, \(summary.unavailableCount) unavailable"
        } else {
            "Incomplete comparisons"
        }
    }
}

private struct BenchmarkOverviewPriorityCard: View {
    let summary: BenchmarkOverviewSummary

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Text("\(summary.needsReviewCount)")
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .accessibilityLabel("\(summary.needsReviewCount) comparisons need review")
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(tint.opacity(0.22))
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        summary.needsReviewCount == 0 ? "No comparison blockers" : "Review priority"
    }

    private var message: String {
        if summary.needsReviewCount == 0 {
            "No regressions, missing data, or unavailable comparisons in this archive."
        } else {
            "\(summary.regressedCount) regressed, \(summary.missingDataCount) missing data, \(summary.unavailableCount) unavailable."
        }
    }

    private var systemImage: String {
        summary.needsReviewCount == 0 ? "checkmark.circle" : "exclamationmark.triangle"
    }

    private var tint: Color {
        summary.needsReviewCount == 0 ? BenchmarkStatusStyle.color(for: .unchanged) : BenchmarkStatusStyle.color(for: .regressed)
    }
}

private struct BenchmarkOverviewCell: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    var status: BenchmarkComparisonStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(status.map { BenchmarkStatusStyle.color(for: $0) } ?? .secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

private extension BenchmarkOverviewSummary {
    var needsReviewCount: Int {
        regressedCount + incompleteCount
    }

    var incompleteCount: Int {
        missingDataCount + unavailableCount
    }

    var comparableCount: Int {
        max(0, totalComparisons - incompleteCount)
    }
}
