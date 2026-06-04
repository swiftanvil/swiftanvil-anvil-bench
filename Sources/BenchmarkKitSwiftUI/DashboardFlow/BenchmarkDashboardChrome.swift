import BenchmarkKit
import SwiftUI

enum BenchmarkDashboardComparisonMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    case previousComparable
    case bestRecent
    case last3
    case last5
    case last10

    static let defaultMode: Self = .previousComparable

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .previousComparable:
            "Previous"
        case .bestRecent:
            "Best Recent"
        case .last3:
            "Last 3"
        case .last5:
            "Last 5"
        case .last10:
            "Last 10"
        }
    }

    var menuTitle: String {
        switch self {
        case .previousComparable:
            "Previous comparable run"
        case .bestRecent:
            "Best recent run"
        case .last3, .last5, .last10:
            "Last \(lastRunLimit) comparable runs"
        }
    }

    var subtitle: String {
        switch self {
        case .previousComparable:
            "Compare the current run to the newest older matching run."
        case .bestRecent:
            "Compare the current run to the strongest recent matching run."
        case .last3, .last5, .last10:
            "Summarize the current run against a comparable last-\(lastRunLimit) window."
        }
    }

    var systemImage: String {
        switch self {
        case .previousComparable:
            "clock.arrow.circlepath"
        case .bestRecent:
            "star.circle"
        case .last3, .last5, .last10:
            "point.3.connected.trianglepath.dotted"
        }
    }

    var lastRunLimit: Int {
        switch self {
        case .previousComparable, .bestRecent:
            1
        case .last3:
            3
        case .last5:
            5
        case .last10:
            10
        }
    }
}

struct BenchmarkComparisonModeLabel: View {
    let mode: BenchmarkDashboardComparisonMode
    let isSelected: Bool

    var body: some View {
        Label(mode.title, systemImage: mode.systemImage)
            .font(.callout.weight(isSelected ? .semibold : .regular))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .background(
                isSelected ? Color.accentColor.opacity(0.14) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.25))
            }
    }
}

struct BenchmarkDisclosureSection<Content: View>: View {
    let title: String
    let subtitle: String?
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        _isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    BenchmarkSectionHeader(title: title, subtitle: subtitle)
                    Spacer(minLength: 12)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BenchmarkActiveFilterPill: View {
    let title: String
    let valueTitle: String
    let clear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(valueTitle)
                    .font(.caption.weight(.semibold))
            }

            Button(action: clear) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
    }
}

struct BenchmarkCompactSummaryRow: View {
    let summary: BenchmarkOverviewSummary

    var body: some View {
        HStack(spacing: 8) {
            BenchmarkSummaryPill(title: "R", count: summary.regressedCount, status: .regressed)
            BenchmarkSummaryPill(title: "I", count: summary.improvedCount, status: .improved)
            BenchmarkSummaryPill(title: "M", count: summary.missingDataCount, status: .missingBaseline)
            BenchmarkSummaryPill(title: "S", count: summary.representedSampleCount, status: .unchanged)
        }
    }
}

struct BenchmarkSummaryPill: View {
    let title: String
    let count: Int
    let status: BenchmarkComparisonStatus

    var body: some View {
        Text("\(title) \(count)")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(BenchmarkStatusStyle.color(for: status).opacity(0.12), in: Capsule())
            .foregroundStyle(BenchmarkStatusStyle.color(for: status))
    }
}

struct BenchmarkMetadataChipRow: View {
    let metadata: [String: String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(metadata.keys.sorted(), id: \.self) { key in
                    if let value = metadata[key] {
                        Text("\(key): \(value)")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.thinMaterial, in: Capsule())
                    }
                }
            }
        }
    }
}
