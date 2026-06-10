import SwiftUI

struct BenchmarkDashboardLoadingView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ProgressView("Loading benchmark history")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.updatesFrequently)

                BenchmarkLoadingSection(title: "Overview")
                BenchmarkLoadingSection(title: "Groups")
                BenchmarkLoadingSection(title: "Comparisons")
            }
            .padding()
        }
    }
}

struct BenchmarkDashboardUnavailableView: View {
    let systemImage: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct BenchmarkDashboardErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        BenchmarkDashboardUnavailableView(
            systemImage: "exclamationmark.triangle",
            title: "History Load Failed",
            message: message,
            actionTitle: "Retry",
            action: retry
        )
    }
}

private struct BenchmarkLoadingSection: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            ForEach(0 ..< 3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(height: 44)
            }
        }
        .accessibilityHidden(true)
    }
}
