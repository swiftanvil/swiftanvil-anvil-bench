import BenchmarkKit
import SwiftUI

#if canImport(Charts)
import Charts
#endif

struct BenchmarkComparisonChartPanel: View {
    let rows: [BenchmarkComparisonRow]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var chartRows: [BenchmarkComparisonChartRow] {
        let comparisonRows = rows
            .compactMap(BenchmarkComparisonChartRow.init(row:))

        let insightRows = comparisonRows.filter(\.shouldRenderTrendContext)
        let hasInsightRows = comparisonRows.contains(where: \.hasInsightContext)
        let visibleRows = hasInsightRows ? insightRows : comparisonRows

        return visibleRows
            .prefix(8)
            .map(\.self)
    }

    private var fallbackMessage: String {
        if rows.contains(where: { $0.insightCard != nil }) {
            return "No meaningful multi-build movements are available for the current filters."
        }

        return "No complete percent deltas are available for the current filters."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BenchmarkSectionHeader(
                title: "Trend Comparison",
                subtitle: "Percent delta for the highest-priority comparisons."
            )

            if chartRows.isEmpty {
                BenchmarkChartFallbackView(message: fallbackMessage)
            } else {
                chartContent

                if chartRows.contains(where: \.hasInsightContext) {
                    BenchmarkComparisonInsightLinkList(rows: chartRows)
                }
            }
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        #if canImport(Charts)
        Chart {
            RuleMark(x: .value("No change", 0.0))
                .foregroundStyle(.secondary.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            ForEach(chartRows) { point in
                BarMark(
                    x: .value("Delta percent", point.deltaPercentage),
                    y: .value("Comparison", point.title)
                )
                .foregroundStyle(BenchmarkStatusStyle.color(for: point.status))
                .accessibilityLabel(point.accessibilityLabel)
            }
        }
        .chartXAxisLabel("Delta percent")
        .chartLegend(.hidden)
        .frame(height: CGFloat(max(180, chartRows.count * 36)))
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        #else
        BenchmarkChartFallbackView(message: accessibilitySummary)
        #endif
    }

    private var accessibilitySummary: String {
        let improved = chartRows.filter { $0.status == .improved }.count
        let regressed = chartRows.filter { $0.status == .regressed }.count
        let largestMovement = chartRows.max { abs($0.deltaPercentage) < abs($1.deltaPercentage) }

        var parts = [
            "Comparison chart with \(chartRows.count) complete percent deltas",
            "\(improved) improved",
            "\(regressed) regressed"
        ]

        if let largestMovement {
            parts.append("largest movement \(largestMovement.title) \(BenchmarkValueFormatter.percent(largestMovement.deltaPercentage))")
        }

        return parts.joined(separator: ", ")
    }
}

private struct BenchmarkComparisonChartRow: Identifiable, Hashable {
    var id: BenchmarkComparisonRow.ID
    var title: String
    var deltaPercentage: Double
    var status: BenchmarkComparisonStatus
    var insightCard: BenchmarkDashboardInsightCard?
    var auditRoute: BenchmarkDrillRoute?

    init?(row: BenchmarkComparisonRow) {
        guard let deltaPercentage = row.comparison.delta?.percentage else {
            return nil
        }

        id = row.id
        title = "\(row.scenario.name) \(row.metric.name)"
        self.deltaPercentage = deltaPercentage
        status = row.status
        insightCard = row.insightCard
        auditRoute = row.currentInsightAuditRoute
    }

    var hasInsightContext: Bool {
        insightCard != nil
    }

    var shouldRenderTrendContext: Bool {
        insightCard?.shouldRenderTrendContext == true
    }

    var insightSummary: String? {
        guard let insightCard else {
            return nil
        }

        return "\(insightCard.classification.chartTitle) | \(insightCard.confidence.chartTitle)"
    }

    var accessibilityLabel: String {
        [
            title,
            BenchmarkValueFormatter.percent(deltaPercentage),
            status.title,
            insightSummary
        ]
        .compactMap(\.self)
        .joined(separator: ", ")
    }
}

private struct BenchmarkComparisonInsightLinkList: View {
    let rows: [BenchmarkComparisonChartRow]

    private var insightRows: [BenchmarkComparisonChartRow] {
        rows.filter(\.hasInsightContext)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BenchmarkSectionHeader(
                title: "Trend Context",
                subtitle: "Meaningful multi-build movements linked to chart and audit detail."
            )

            ForEach(insightRows) { row in
                BenchmarkComparisonInsightLinkRow(row: row)
            }
        }
    }
}

private struct BenchmarkComparisonInsightLinkRow: View {
    let row: BenchmarkComparisonChartRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                if let insightSummary = row.insightSummary {
                    Text(insightSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            NavigationLink(value: row.id) {
                Label("Chart", systemImage: "chart.xyaxis.line")
            }
            .buttonStyle(.borderless)

            if let auditRoute = row.auditRoute {
                NavigationLink(value: auditRoute) {
                    Label("Audit", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
    }
}

struct BenchmarkChartFallbackView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary)
            }
    }
}

private extension BenchmarkComparisonRow {
    var currentInsightAuditRoute: BenchmarkDrillRoute? {
        guard let insightCard else {
            return nil
        }

        let currentPoint = history.sortedPoints.last {
            $0.scope == .current && $0.runID == insightCard.current.run.id
        } ?? history.sortedPoints.last {
            $0.scope == .current
        }

        return currentPoint.map { BenchmarkDrillRoute(rowID: id, sampleID: $0.id) }
    }
}

private extension BenchmarkDashboardInsightCard {
    var shouldRenderTrendContext: Bool {
        switch classification {
        case .improving, .regressing, .volatile, .recovered:
            true
        case .stable, .missingBaseline:
            false
        }
    }
}

private extension BenchmarkTrendClassification {
    var chartTitle: String {
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
            "Missing baseline"
        }
    }
}

private extension BenchmarkTrendConfidence {
    var chartTitle: String {
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
