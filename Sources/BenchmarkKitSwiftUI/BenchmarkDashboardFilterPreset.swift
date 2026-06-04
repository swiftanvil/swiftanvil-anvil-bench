import SwiftUI

enum BenchmarkDashboardFilterPreset: String, CaseIterable, Identifiable {
    case product
    case qa
    case developerAudit
    case releaseCandidate

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .product:
            "Product"
        case .qa:
            "QA"
        case .developerAudit:
            "Developer/Audit"
        case .releaseCandidate:
            "Release Candidate"
        }
    }

    var iconName: String {
        switch self {
        case .product:
            "chart.line.uptrend.xyaxis"
        case .qa:
            "checkmark.shield"
        case .developerAudit:
            "stethoscope"
        case .releaseCandidate:
            "flag.checkered"
        }
    }

    func apply(to filters: inout BenchmarkDashboardFilterState) {
        switch self {
        case .product:
            filters.archiveSelection = .active
            filters.dateFilter = .last30Days
            filters.statusFilter = .all
        case .qa:
            filters.archiveSelection = .active
            filters.dateFilter = .last7Days
            filters.statusFilter = .regressed
        case .developerAudit:
            filters.archiveSelection = .all
            filters.dateFilter = .all
            filters.statusFilter = .all
        case .releaseCandidate:
            filters.archiveSelection = .active
            filters.dateFilter = .last7Days
            filters.statusFilter = .missingData
        }
    }

    func matches(_ filters: BenchmarkDashboardFilterState) -> Bool {
        switch self {
        case .product:
            filters.archiveSelection == .active &&
                filters.dateFilter == .last30Days &&
                filters.statusFilter == .all
        case .qa:
            filters.archiveSelection == .active &&
                filters.dateFilter == .last7Days &&
                filters.statusFilter == .regressed
        case .developerAudit:
            filters.archiveSelection == .all &&
                filters.dateFilter == .all &&
                filters.statusFilter == .all
        case .releaseCandidate:
            filters.archiveSelection == .active &&
                filters.dateFilter == .last7Days &&
                filters.statusFilter == .missingData
        }
    }
}

struct BenchmarkDashboardFilterPresetLabel: View {
    let preset: BenchmarkDashboardFilterPreset
    let isSelected: Bool

    var body: some View {
        Label(preset.title, systemImage: preset.iconName)
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
