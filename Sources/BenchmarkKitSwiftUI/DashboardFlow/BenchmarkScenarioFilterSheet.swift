import BenchmarkKit
import SwiftUI

struct BenchmarkScenarioFilterSheet: View {
    let dimensions: [BenchmarkComparisonDimensionGroup]
    @Binding var selectedComparisonDimensionValues: [BenchmarkComparisonDimension.ID: BenchmarkComparisonDimensionValue]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Presets") {
                ForEach(BenchmarkScenarioFilterPreset.allCases) { preset in
                    Button(action: { apply(preset) }) {
                        BenchmarkFilterValueRow(
                            title: preset.title,
                            subtitle: preset.subtitle,
                            isSelected: preset.matches(selectedComparisonDimensionValues, dimensions: dimensions)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(preset.canApply(to: dimensions) == false)
                }
            }

            if activeFilterValues.isEmpty == false {
                Section("Active Filters") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(activeFilterValues) { filterValue in
                                BenchmarkActiveFilterPill(
                                    title: filterValue.dimensionTitle,
                                    valueTitle: filterValue.title
                                ) {
                                    clear(dimension: filterValue.dimension)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if dimensions.isEmpty {
                Section {
                    Text("No scenario-specific compare filters are available for this dataset yet.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(dimensions) { group in
                    Section(group.dimension.title) {
                        Button {
                            clear(dimension: group.dimension)
                        } label: {
                            BenchmarkFilterValueRow(
                                title: "All \(group.dimension.title)",
                                subtitle: "Remove this filter and compare the full scenario set again.",
                                isSelected: isOptionClear(group.dimension)
                            )
                        }
                        .buttonStyle(.plain)

                        ForEach(group.values) { value in
                            Button {
                                select(value, for: group.dimension)
                            } label: {
                                BenchmarkFilterValueRow(
                                    title: value.title,
                                    subtitle: value.subtitle,
                                    isSelected: isSelected(value, for: group.dimension)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Filters")
        #if os(iOS) || os(tvOS) || os(watchOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Close") {
                        dismiss()
                    }
                }

                if selectedComparisonDimensionValues.isEmpty == false {
                    ToolbarItem(placement: .automatic) {
                        Button("Clear All") {
                            selectedComparisonDimensionValues.removeAll()
                        }
                    }
                }
            }
    }

    private var activeFilterValues: [BenchmarkSelectedComparisonDimensionValue] {
        dimensions.compactMap { group in
            group.values.first(where: { isSelected($0, for: group.dimension) }).map {
                BenchmarkSelectedComparisonDimensionValue(
                    dimension: group.dimension,
                    value: $0,
                    title: $0.title,
                    subtitle: $0.subtitle
                )
            }
        }
    }

    private func apply(_ preset: BenchmarkScenarioFilterPreset) {
        selectedComparisonDimensionValues = preset.selection(from: dimensions)
    }

    private func select(_ value: BenchmarkComparisonDimensionValue, for dimension: BenchmarkComparisonDimension) {
        clear(dimension: dimension)
        selectedComparisonDimensionValues[dimension.id] = value
    }

    private func clear(dimension: BenchmarkComparisonDimension) {
        selectedComparisonDimensionValues.removeValue(forKey: dimension.id)
    }

    private func isSelected(
        _ value: BenchmarkComparisonDimensionValue,
        for dimension: BenchmarkComparisonDimension
    ) -> Bool {
        selectedComparisonDimensionValues[dimension.id]?.id == value.id
    }

    private func isOptionClear(_ dimension: BenchmarkComparisonDimension) -> Bool {
        selectedComparisonDimensionValues[dimension.id] == nil
    }
}

private enum BenchmarkScenarioFilterPreset: String, CaseIterable, Identifiable {
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

    var subtitle: String {
        switch self {
        case .product:
            "Clear scenario-specific filters for the broad product view."
        case .qa:
            "Prefer release or QA-like configurations when present."
        case .developerAudit:
            "Prefer feature, debug, or audit-oriented slices when present."
        case .releaseCandidate:
            "Prefer release-candidate, release, or mainline slices when present."
        }
    }

    func canApply(to dimensions: [BenchmarkComparisonDimensionGroup]) -> Bool {
        self == .product || selection(from: dimensions).isEmpty == false
    }

    func matches(
        _ selectedValues: [BenchmarkComparisonDimension.ID: BenchmarkComparisonDimensionValue],
        dimensions: [BenchmarkComparisonDimensionGroup]
    ) -> Bool {
        selectedValues == selection(from: dimensions)
    }

    func selection(
        from dimensions: [BenchmarkComparisonDimensionGroup]
    ) -> [BenchmarkComparisonDimension.ID: BenchmarkComparisonDimensionValue] {
        switch self {
        case .product:
            [:]
        case .qa:
            selection(
                from: dimensions,
                rules: [
                    BenchmarkScenarioFilterPresetRule(
                        dimensionTerms: ["configuration", "profile"],
                        valueTerms: ["qa", "test", "release"]
                    ),
                    BenchmarkScenarioFilterPresetRule(
                        dimensionTerms: ["branch"],
                        valueTerms: ["main", "release"]
                    )
                ]
            )
        case .developerAudit:
            selection(
                from: dimensions,
                rules: [
                    BenchmarkScenarioFilterPresetRule(
                        dimensionTerms: ["configuration", "profile"],
                        valueTerms: ["debug", "audit", "dev"]
                    ),
                    BenchmarkScenarioFilterPresetRule(
                        dimensionTerms: ["branch"],
                        valueTerms: ["feature", "develop", "main"]
                    )
                ]
            )
        case .releaseCandidate:
            selection(
                from: dimensions,
                rules: [
                    BenchmarkScenarioFilterPresetRule(
                        dimensionTerms: ["configuration", "build", "branch"],
                        valueTerms: ["release candidate", "rc", "release"]
                    ),
                    BenchmarkScenarioFilterPresetRule(
                        dimensionTerms: ["branch"],
                        valueTerms: ["main"]
                    )
                ]
            )
        }
    }

    private func selection(
        from dimensions: [BenchmarkComparisonDimensionGroup],
        rules: [BenchmarkScenarioFilterPresetRule]
    ) -> [BenchmarkComparisonDimension.ID: BenchmarkComparisonDimensionValue] {
        var selectedValues: [BenchmarkComparisonDimension.ID: BenchmarkComparisonDimensionValue] = [:]

        for rule in rules {
            guard let match = firstMatch(in: dimensions, for: rule) else {
                continue
            }

            selectedValues[match.dimension.id] = match.value
        }

        return selectedValues
    }

    private func firstMatch(
        in dimensions: [BenchmarkComparisonDimensionGroup],
        for rule: BenchmarkScenarioFilterPresetRule
    ) -> (dimension: BenchmarkComparisonDimension, value: BenchmarkComparisonDimensionValue)? {
        for group in dimensions where rule.matches(dimension: group.dimension) {
            if let value = group.values.first(where: rule.matches(value:)) {
                return (group.dimension, value)
            }
        }

        return nil
    }
}

private struct BenchmarkScenarioFilterPresetRule {
    let dimensionTerms: [String]
    let valueTerms: [String]

    func matches(dimension: BenchmarkComparisonDimension) -> Bool {
        let title = dimension.title.lowercased()
        let id = dimension.id.rawValue.lowercased()

        return dimensionTerms.contains { title.contains($0) || id.contains($0) }
    }

    func matches(value: BenchmarkComparisonDimensionValue) -> Bool {
        let title = value.title.lowercased()
        let subtitle = value.subtitle?.lowercased() ?? ""
        let id = value.id.rawValue.lowercased()

        return valueTerms.contains { term in
            title.contains(term) || subtitle.contains(term) || id.contains(term)
        }
    }
}

struct BenchmarkFilterValueRow: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}
