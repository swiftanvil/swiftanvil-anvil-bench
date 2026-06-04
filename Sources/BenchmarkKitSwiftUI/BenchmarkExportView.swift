import SwiftUI

struct BenchmarkExportView: View {
    let title: String
    let subtitle: String
    let payload: String

    private var payloadLineCount: Int {
        max(payload.split(whereSeparator: \.isNewline).count, payload.isEmpty ? 0 : 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BenchmarkSectionHeader(title: title, subtitle: subtitle)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ShareLink(item: payload) {
                        Label("Share Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(payload.isEmpty)
                    .accessibilityLabel("Share benchmark export")

                    Text("\(payloadLineCount) line\(payloadLineCount == 1 ? "" : "s")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(payload)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(12)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary)
            }
        }
    }
}
