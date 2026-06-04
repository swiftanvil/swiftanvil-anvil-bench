import BenchmarkKit
import SwiftUI

struct BenchmarkSectionHeader: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct BenchmarkStatusBadge: View {
    let status: BenchmarkComparisonStatus

    var body: some View {
        Label(status.title, systemImage: status.systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(BenchmarkStatusStyle.color(for: status))
            .background(BenchmarkStatusStyle.color(for: status).opacity(0.12), in: Capsule())
            .accessibilityLabel(status.title)
    }
}

struct BenchmarkValueField: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}

struct BenchmarkInsightCard: View {
    let row: BenchmarkComparisonRow
    let insight: BenchmarkComparisonInsight
    let dismiss: () -> Void

    private var tint: Color {
        switch insight.kind {
        case .regression:
            BenchmarkStatusStyle.color(for: .regressed)
        case .improvement:
            BenchmarkStatusStyle.color(for: .improved)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(insight.kind.title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)

                Spacer(minLength: 8)

                Button("Dismiss", systemImage: "xmark.circle", action: dismiss)
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .accessibilityLabel("Dismiss benchmark insight")
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(insight.title)
                    .font(.headline)

                Text(insight.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            NavigationLink(value: row.id) {
                Label("Review Details", systemImage: "chart.xyaxis.line")
                    .font(.subheadline.weight(.semibold))
            }
            .accessibilityHint("Opens the benchmark metric detail.")
        }
        .padding(.vertical, 6)
    }

    private var systemImage: String {
        switch insight.kind {
        case .regression:
            "exclamationmark.triangle"
        case .improvement:
            "checkmark.circle"
        }
    }
}

struct BenchmarkRelatedPerformanceChangeNotesView: View {
    let notes: [BenchmarkRelatedPerformanceChangeNote]

    var body: some View {
        if notes.isEmpty == false {
            VStack(alignment: .leading, spacing: 12) {
                BenchmarkSectionHeader(
                    title: "Likely Related Changes",
                    subtitle: "Performance change notes that match this benchmark and build window. Treat them as correlation signals, not proof of cause."
                )

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(notes, id: \.note.id) { relatedNote in
                        BenchmarkRelatedPerformanceChangeNoteRow(relatedNote: relatedNote)
                    }
                }
            }
        }
    }
}

private struct BenchmarkRelatedPerformanceChangeNoteRow: View {
    let relatedNote: BenchmarkRelatedPerformanceChangeNote

    private var note: BenchmarkPerformanceChangeNote {
        relatedNote.note
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("May correlate with this comparison", systemImage: "link")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(note.summary)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], alignment: .leading, spacing: 10) {
                BenchmarkValueField(title: "Area", value: note.area.description)
                BenchmarkValueField(title: "Change Type", value: note.changeType.displayTitle)
                BenchmarkValueField(title: "Expected Direction", value: note.expectedImpact.displayTitle)
                BenchmarkValueField(title: "Risk", value: note.risk.displayTitle)
                BenchmarkValueField(title: "Introduced Build", value: note.buildIntroduced.displayTitle)
                BenchmarkValueField(title: "Match Basis", value: relatedNote.matchBasisTitle)
            }

            if note.validationNotes.isEmpty == false {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Validation notes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(note.validationNotes, id: \.self) { validationNote in
                        Label(validationNote, systemImage: "checklist")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
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
    }
}

private extension BenchmarkRelatedPerformanceChangeNote {
    var matchBasisTitle: String {
        matchedScopes
            .sorted(by: { $0.displaySortOrder < $1.displaySortOrder })
            .map(\.displayTitle)
            .joined(separator: ", ")
    }
}

private extension BenchmarkRelatedPerformanceChangeNoteScope {
    var displayTitle: String {
        switch self {
        case .metric:
            "Metric"
        case .scenario:
            "Scenario"
        case .suite:
            "Suite"
        case .scenarioFingerprint:
            "Scenario fingerprint"
        case .workflowFamily:
            "Workflow family"
        case .historyScope:
            "History scope"
        }
    }

    var displaySortOrder: Int {
        switch self {
        case .metric:
            0
        case .scenario:
            1
        case .suite:
            2
        case .scenarioFingerprint:
            3
        case .workflowFamily:
            4
        case .historyScope:
            5
        }
    }
}

private extension BenchmarkPerformanceChangeType {
    var displayTitle: String {
        switch self {
        case .feature:
            "Feature"
        case .optimization:
            "Optimization"
        case .refactor:
            "Refactor"
        case .configuration:
            "Configuration"
        case .dependency:
            "Dependency"
        case .instrumentation:
            "Instrumentation"
        case .experiment:
            "Experiment"
        }
    }
}

private extension BenchmarkPerformanceExpectedImpact {
    var displayTitle: String {
        switch self {
        case .improvesPerformance:
            "Expected improvement"
        case .regressesPerformance:
            "Expected regression"
        case .mixed:
            "Mixed"
        case .neutral:
            "Neutral"
        case .unknown:
            "Unknown"
        }
    }
}

private extension BenchmarkPerformanceChangeRisk {
    var displayTitle: String {
        switch self {
        case .low:
            "Low"
        case .medium:
            "Medium"
        case .high:
            "High"
        case .unknown:
            "Unknown"
        }
    }
}

private extension BenchmarkPerformanceChangeBuild {
    var displayTitle: String {
        if let version = bundleShortVersion, version.isEmpty == false {
            return "\(version) (\(bundleBuildNumber))"
        }

        return bundleBuildNumber
    }
}
