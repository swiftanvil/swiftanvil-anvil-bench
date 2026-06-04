import BenchmarkKit
import SwiftUI

struct BenchmarkDetailContextView: View {
    let row: BenchmarkComparisonRow
    var showsRelatedPerformanceChangeNotes = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BenchmarkSectionHeader(
                title: "Run Context",
                subtitle: "Run metadata behind the baseline and current samples."
            )

            if row.matrixContexts.isEmpty {
                Text("No run matrix context is available for this metric.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(row.matrixContexts) { context in
                            BenchmarkMatrixContextRow(context: context)
                                .frame(width: 320, alignment: .leading)
                        }
                    }
                }
            }

            if showsRelatedPerformanceChangeNotes {
                BenchmarkRelatedPerformanceChangeNotesView(notes: row.comparison.relatedPerformanceChangeNotes)
            }
        }
    }
}

private struct BenchmarkMatrixContextRow: View {
    let context: BenchmarkRunMatrixContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(context.scope.title)
                    .font(.subheadline.weight(.semibold))

                Text(BenchmarkValueFormatter.date(context.startedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Text(context.archiveState.rawValue.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(context.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            if context.metadata.isEmpty == false {
                BenchmarkMetadataFlow(metadata: context.metadata)
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

private struct BenchmarkMetadataFlow: View {
    let metadata: [String: String]

    private var metadataPairs: [(key: String, value: String)] {
        metadata
            .map { (key: $0.key, value: $0.value) }
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(metadataPairs, id: \.key) { pair in
                Text("\(pair.key): \(pair.value)")
                    .font(.caption)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
            }
        }
    }
}

struct BenchmarkConfidenceView: View {
    let confidence: BenchmarkComparisonConfidence

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(confidence.level.title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)

            Text(confidence.summary)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.35))
        }
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch confidence.level {
        case .high:
            .green
        case .medium:
            .orange
        case .low:
            .red
        case .unavailable:
            .secondary
        }
    }

    private var systemImage: String {
        switch confidence.level {
        case .high:
            "checkmark.seal"
        case .medium:
            "exclamationmark.triangle"
        case .low:
            "exclamationmark.circle"
        case .unavailable:
            "questionmark.circle"
        }
    }
}
