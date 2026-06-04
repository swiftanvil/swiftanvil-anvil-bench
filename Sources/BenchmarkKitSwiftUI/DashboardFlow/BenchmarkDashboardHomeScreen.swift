import BenchmarkKit
import SwiftUI

struct BenchmarkDashboardHomeScreen: View {
    let loadedState: BenchmarkDashboardLoadedState

    @State private var selectedMode = BenchmarkDashboardMode.defaultMode
    @State private var isOverviewExpanded = true
    @State private var isRegressionExpanded = true
    @State private var isImprovementExpanded = true
    @State private var isTrendExpanded = true
    @State private var isRecentExpanded = false
    @State private var isSuitesExpanded = false

    private var defaultState: BenchmarkDashboardDefaultState {
        loadedState.defaultState
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                modePicker

                switch selectedMode {
                case .summary:
                    summaryContent
                case .suites:
                    suitesSection
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: selectedMode) { newMode in
            if newMode == .suites {
                isSuitesExpanded = true
            }
        }
    }

    private var modePicker: some View {
        Picker("Dashboard Mode", selection: $selectedMode) {
            ForEach(BenchmarkDashboardMode.allCases, id: \.self) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Dashboard mode")
    }

    @ViewBuilder
    private var summaryContent: some View {
        BenchmarkDisclosureSection(
            title: defaultState.mode.title,
            subtitle: overviewSubtitle,
            isExpanded: $isOverviewExpanded
        ) {
            VStack(alignment: .leading, spacing: 16) {
                BenchmarkOverviewSummarySection(summary: loadedState.overview)

                if let currentBaseline = defaultState.currentBaseline {
                    NavigationLink(value: currentBaseline.id) {
                        BenchmarkMetricHeroCard(
                            row: currentBaseline,
                            title: "Current Baseline",
                            subtitle: "Baseline, current, and delta for the highest priority comparison.",
                            showsContextSubtitle: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        topRegressionsSection
        topImprovementsSection
        primaryTrendSection
        recentScenariosSection
        suitesSection
    }

    @ViewBuilder
    private var topRegressionsSection: some View {
        if defaultState.topRegressions.isEmpty == false {
            BenchmarkDisclosureSection(
                title: "Top Regressions",
                subtitle: "Largest current regressions by percent delta.",
                isExpanded: $isRegressionExpanded
            ) {
                BenchmarkComparisonListView(
                    title: "Top Regressions",
                    subtitle: nil,
                    rows: defaultState.topRegressions
                )
            }
        }
    }

    @ViewBuilder
    private var topImprovementsSection: some View {
        if defaultState.topImprovements.isEmpty == false {
            BenchmarkDisclosureSection(
                title: "Top Improvements",
                subtitle: "Largest current improvements by percent delta.",
                isExpanded: $isImprovementExpanded
            ) {
                BenchmarkComparisonListView(
                    title: "Top Improvements",
                    subtitle: nil,
                    rows: defaultState.topImprovements
                )
            }
        }
    }

    @ViewBuilder
    private var primaryTrendSection: some View {
        if let primaryTrend = defaultState.primaryTrend {
            BenchmarkDisclosureSection(
                title: "Primary Trend",
                subtitle: "\(primaryTrend.metric.name) across baseline and current samples.",
                isExpanded: $isTrendExpanded
            ) {
                NavigationLink(value: primaryTrend.id) {
                    BenchmarkTrendChartView(row: primaryTrend)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var recentScenariosSection: some View {
        if loadedState.recentScenarios.isEmpty == false {
            BenchmarkDisclosureSection(
                title: "Last 3 Scenarios",
                subtitle: "Jump straight into the most recently observed scenario details.",
                isExpanded: $isRecentExpanded
            ) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(loadedState.recentScenarios) { recentScenario in
                            NavigationLink(
                                value: BenchmarkScenarioRoute(
                                    suite: recentScenario.suite,
                                    scenario: recentScenario.scenario,
                                    metricID: nil
                                )
                            ) {
                                BenchmarkRecentScenarioCard(entry: recentScenario)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var suitesSection: some View {
        BenchmarkDisclosureSection(
            title: "Suites",
            subtitle: "Start from the module or submodule you want to inspect, then drill into scenarios and metrics.",
            isExpanded: $isSuitesExpanded
        ) {
            LazyVStack(spacing: 12) {
                ForEach(loadedState.groups) { group in
                    NavigationLink(value: BenchmarkSuiteRoute(suiteID: group.suite.id)) {
                        BenchmarkSuiteCard(group: group)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var overviewSubtitle: String {
        var parts = ["Archive: \(loadedState.overview.archiveSelection.title)"]

        if let latestRunStartedAt = loadedState.overview.latestRunStartedAt {
            parts.append("Latest run: \(BenchmarkValueFormatter.date(latestRunStartedAt))")
        }

        return parts.joined(separator: " | ")
    }
}
