import BenchmarkKit
import Foundation

/// Demo fixtures and history data sources for previews, tests, and manual dashboard tuning.
public enum BenchmarkDashboardDemoData {
    /// A catalog that contains active, archived, missing, neutral, improved, regressed, volatile, and recovered examples.
    public static let catalog = BenchmarkDashboardCatalog(
        suites: [
            renderingSuite,
            storageSuite,
            buildSuite,
            BenchmarkExportBlocking.suite
        ],
        scenarios: [
            launchScenario,
            scrollingScenario,
            importScenario,
            archivedScenario,
            compileScenario,
            volatileScenario,
            recoveredScenario,
            BenchmarkExportBlocking.collageScenario
        ],
        metrics: [
            latencyMetric,
            throughputMetric,
            memoryMetric,
            qualityMetric,
            payloadMetric,
            cacheMetric,
            buildTimeMetric,
            BenchmarkExportBlocking.perceivedBlockingDurationMetric
        ],
        comparisonDimensions: ComparisonDimensions.all
    )

    /// Dashboard presentation that splits demo samples by baseline and current tags.
    public static let presentation = BenchmarkDashboardPresentation(
        title: "Benchmark Dashboard Demo",
        baseline: BenchmarkDashboardHistoryScope(name: "Baseline", tagIDs: [baselineTag.id]),
        current: BenchmarkDashboardHistoryScope(name: "Current", tagIDs: [currentTag.id]),
        initialArchiveFilter: .active,
        comparisonDimensions: ComparisonDimensions.all,
        lowSampleThreshold: 2
    )

    /// Backward-compatible name for the demo dashboard presentation.
    public static let configuration = presentation

    /// A populated history snapshot with representative dashboard states.
    public static let populatedDataSource = BenchmarkHistorySnapshot(
        runs: activeRuns + archivedRuns,
        samples: activeSamples + archivedSamples
    )

    /// An empty history snapshot for empty-state previews.
    public static let emptyDataSource = BenchmarkHistorySnapshot()

    /// A throwing history data source for error-state previews.
    public static let errorDataSource = BenchmarkDashboardFailingHistoryDataSource()
}

/// An error thrown by the demo failing history data source.
public enum BenchmarkDashboardDemoError: Error, LocalizedError, Sendable {
    /// Demo history is unavailable.
    case historyUnavailable

    /// A localized description of the demo error.
    public var errorDescription: String? {
        "Demo benchmark history is unavailable."
    }
}

/// A history data source that always throws a demo error.
public struct BenchmarkDashboardFailingHistoryDataSource: BenchmarkHistoryDataSource {
    /// Creates a failing demo history data source.
    public init() {}

    /// Throws a demo error instead of returning runs.
    public func runs(matching query: BenchmarkRunQuery) async throws -> [BenchmarkRun] {
        throw BenchmarkDashboardDemoError.historyUnavailable
    }

    /// Throws a demo error instead of returning samples.
    public func samples(matching query: BenchmarkSampleQuery) async throws -> [BenchmarkSample] {
        throw BenchmarkDashboardDemoError.historyUnavailable
    }
}

private extension BenchmarkDashboardDemoData {
    static let baselineTag = BenchmarkTag(id: "baseline", name: "Baseline")
    static let currentTag = BenchmarkTag(id: "current", name: "Current")
    static let smokeTag = BenchmarkTag(id: "smoke", name: "Smoke")

    static let renderingSuite = BenchmarkSuite(
        id: "suite.rendering",
        name: "Rendering",
        tags: [smokeTag]
    )
    static let storageSuite = BenchmarkSuite(
        id: "suite.storage",
        name: "Storage",
        tags: [smokeTag]
    )
    static let buildSuite = BenchmarkSuite(
        id: "suite.build",
        name: "Build",
        tags: [smokeTag]
    )

    static let launchScenario = BenchmarkScenario(
        id: "scenario.launch",
        suiteID: renderingSuite.id,
        name: "Launch",
        presentation: BenchmarkScenarioPresentation(
            primaryMetricID: latencyMetric.id,
            metricOrder: [latencyMetric.id, memoryMetric.id, throughputMetric.id]
        )
    )
    static let scrollingScenario = BenchmarkScenario(
        id: "scenario.scrolling",
        suiteID: renderingSuite.id,
        name: "Scrolling"
    )
    static let importScenario = BenchmarkScenario(
        id: "scenario.import",
        suiteID: storageSuite.id,
        name: "Import"
    )
    static let archivedScenario = BenchmarkScenario(
        id: "scenario.archived",
        suiteID: storageSuite.id,
        name: "Archived Batch"
    )
    static let compileScenario = BenchmarkScenario(
        id: "scenario.compile",
        suiteID: buildSuite.id,
        name: "Compile",
        presentation: BenchmarkScenarioPresentation(
            primaryMetricID: buildTimeMetric.id,
            metricOrder: [buildTimeMetric.id]
        )
    )
    static let volatileScenario = BenchmarkScenario(
        id: "scenario.volatile",
        suiteID: buildSuite.id,
        name: "Volatile Build Trend",
        presentation: BenchmarkScenarioPresentation(
            primaryMetricID: buildTimeMetric.id,
            metricOrder: [buildTimeMetric.id]
        )
    )
    static let recoveredScenario = BenchmarkScenario(
        id: "scenario.recovered",
        suiteID: buildSuite.id,
        name: "Recovered Build Trend",
        presentation: BenchmarkScenarioPresentation(
            primaryMetricID: buildTimeMetric.id,
            metricOrder: [buildTimeMetric.id]
        )
    )

    static let latencyMetric = BenchmarkMetric(
        id: "metric.latency",
        name: "Latency",
        unit: .milliseconds,
        direction: .lowerIsBetter
    )
    static let throughputMetric = BenchmarkMetric(
        id: "metric.throughput",
        name: "Throughput",
        unit: .count,
        direction: .higherIsBetter
    )
    static let memoryMetric = BenchmarkMetric(
        id: "metric.memory",
        name: "Memory",
        unit: .bytes,
        direction: .lowerIsBetter
    )
    static let qualityMetric = BenchmarkMetric(
        id: "metric.quality",
        name: "Quality Score",
        unit: .score,
        direction: .neutral
    )
    static let payloadMetric = BenchmarkMetric(
        id: "metric.payload",
        name: "Payload Size",
        unit: .bytes,
        direction: .lowerIsBetter
    )
    static let cacheMetric = BenchmarkMetric(
        id: "metric.cache",
        name: "Cache Hits",
        unit: .count,
        direction: .higherIsBetter
    )
    static let buildTimeMetric = BenchmarkMetric(
        id: "metric.build-time",
        name: "Build Time",
        unit: .seconds,
        direction: .lowerIsBetter
    )

    enum ComparisonDimensions {
        static let device = BenchmarkComparisonDimension(
            id: "dimension.device",
            title: "Device",
            kind: .singleKey,
            visibility: .both,
            keys: ["device"]
        )

        static let os = BenchmarkComparisonDimension(
            id: "dimension.os",
            title: "OS",
            kind: .singleKey,
            visibility: .context,
            keys: ["os"]
        )

        static let build = BenchmarkComparisonDimension(
            id: "dimension.build",
            title: "Build",
            kind: .singleKey,
            visibility: .both,
            keys: ["build"]
        )

        static let branch = BenchmarkComparisonDimension(
            id: "dimension.branch",
            title: "Branch",
            kind: .singleKey,
            visibility: .both,
            keys: ["branch"]
        )

        static let configuration = BenchmarkComparisonDimension(
            id: "dimension.configuration",
            title: "Configuration",
            kind: .singleKey,
            visibility: .context,
            keys: ["configuration"]
        )
        static let profile = BenchmarkComparisonDimension(
            id: "dimension.profile",
            title: "Profile",
            kind: .singleKey,
            visibility: .both,
            keys: ["profile"]
        )
        static let exportRoute = BenchmarkComparisonDimension(
            id: "dimension.export-route",
            title: "Export Route",
            kind: .singleKey,
            visibility: .both,
            keys: ["exportRoute"]
        )
        static let samplingProfile = BenchmarkComparisonDimension(
            id: "dimension.sampling-profile",
            title: "Sampling Profile",
            kind: .singleKey,
            visibility: .filter,
            keys: ["samplingProfile"]
        )

        static let runIdentity = BenchmarkComparisonDimension(
            id: "dimension.run-identity",
            title: "Run Identity",
            kind: .identity,
            visibility: .filter,
            keys: ["device", "os", "build", "branch"]
        )

        static let all: [BenchmarkComparisonDimension] = [
            device,
            os,
            build,
            branch,
            configuration,
            profile,
            exportRoute,
            samplingProfile,
            runIdentity
        ]
    }

    static let activeRuns: [BenchmarkRun] = [
        run(
            id: "run.active.baseline",
            suiteID: renderingSuite.id,
            scenarioID: launchScenario.id,
            startedAt: 1_777_700_000,
            archiveState: .active,
            metadata: ["device": "Simulator", "os": "26.0", "build": "100", "branch": "main"]
        ),
        run(
            id: "run.active.current",
            suiteID: renderingSuite.id,
            scenarioID: launchScenario.id,
            startedAt: 1_777_786_400,
            archiveState: .active,
            metadata: ["device": "Simulator", "os": "26.0", "build": "101", "branch": "feature"],
            performanceChangeNotes: [launchOptimizationNote]
        ),
        run(
            id: "run.active.baseline.phone",
            suiteID: renderingSuite.id,
            scenarioID: launchScenario.id,
            startedAt: 1_777_700_900,
            archiveState: .active,
            metadata: ["device": "Phone 16", "os": "26.0", "build": "100", "branch": "main", "configuration": "release"]
        ),
        run(
            id: "run.active.current.phone",
            suiteID: renderingSuite.id,
            scenarioID: launchScenario.id,
            startedAt: 1_777_787_300,
            archiveState: .active,
            metadata: ["device": "Phone 16", "os": "26.0", "build": "101", "branch": "feature", "configuration": "release"]
        ),
        run(
            id: "run.scrolling.baseline",
            suiteID: renderingSuite.id,
            scenarioID: scrollingScenario.id,
            startedAt: 1_777_710_000,
            archiveState: .active,
            metadata: ["device": "Tablet", "os": "26.0", "build": "100"]
        ),
        run(
            id: "run.scrolling.current",
            suiteID: renderingSuite.id,
            scenarioID: scrollingScenario.id,
            startedAt: 1_777_796_400,
            archiveState: .active,
            metadata: ["device": "Tablet", "os": "26.0", "build": "101"]
        ),
        run(
            id: "run.import.baseline",
            suiteID: storageSuite.id,
            scenarioID: importScenario.id,
            startedAt: 1_777_720_000,
            archiveState: .active,
            metadata: ["device": "Simulator", "os": "26.0", "build": "100"]
        ),
        run(
            id: "run.import.current",
            suiteID: storageSuite.id,
            scenarioID: importScenario.id,
            startedAt: 1_777_806_400,
            archiveState: .active,
            metadata: ["device": "Simulator", "os": "26.0", "build": "101"]
        ),
        run(
            id: "run.build.baseline",
            suiteID: buildSuite.id,
            scenarioID: compileScenario.id,
            startedAt: 1_777_730_000,
            archiveState: .active,
            metadata: ["device": "CI Mac mini", "os": "15.5", "build": "100", "branch": "main", "configuration": "release"]
        ),
        run(
            id: "run.build.current",
            suiteID: buildSuite.id,
            scenarioID: compileScenario.id,
            startedAt: 1_777_816_400,
            archiveState: .active,
            metadata: ["device": "CI Mac mini", "os": "15.5", "build": "101", "branch": "feature", "configuration": "release"],
            performanceChangeNotes: [documentationOnlyNote]
        ),
        run(
            id: "run.export.baseline",
            suiteID: BenchmarkExportBlocking.suite.id,
            scenarioID: BenchmarkExportBlocking.collageScenario.id,
            startedAt: 1_777_742_000,
            archiveState: .active,
            metadata: exportMetadata(
                build: "200",
                branch: "main",
                configuration: "release",
                profile: "qa",
                exportRoute: "native",
                samplingProfile: .light,
                bundleBuildNumber: "4200"
            )
        ),
        run(
            id: "run.export.current",
            suiteID: BenchmarkExportBlocking.suite.id,
            scenarioID: BenchmarkExportBlocking.collageScenario.id,
            startedAt: 1_777_828_400,
            archiveState: .active,
            metadata: exportMetadata(
                build: "201",
                branch: "release-candidate",
                configuration: "release candidate",
                profile: "audit",
                exportRoute: "imgly",
                samplingProfile: .deep,
                bundleBuildNumber: "4201"
            ),
            performanceChangeNotes: [exportRouteRiskNote]
        )
    ]

    static let archivedRuns: [BenchmarkRun] = [
        run(
            id: "run.archived.baseline",
            suiteID: storageSuite.id,
            scenarioID: archivedScenario.id,
            startedAt: 1_776_000_000,
            archiveState: .archived,
            metadata: ["device": "Simulator", "os": "25.4", "build": "90"]
        ),
        run(
            id: "run.archived.current",
            suiteID: storageSuite.id,
            scenarioID: archivedScenario.id,
            startedAt: 1_776_086_400,
            archiveState: .archived,
            metadata: ["device": "Simulator", "os": "25.4", "build": "91"]
        ),
        run(
            id: "run.volatile.baseline.1",
            suiteID: buildSuite.id,
            scenarioID: volatileScenario.id,
            startedAt: 1_776_100_000,
            archiveState: .archived,
            metadata: ["device": "CI Mac mini", "os": "15.5", "build": "80", "branch": "main", "trendStory": "volatile"]
        ),
        run(
            id: "run.volatile.current.1",
            suiteID: buildSuite.id,
            scenarioID: volatileScenario.id,
            startedAt: 1_776_186_400,
            archiveState: .archived,
            metadata: ["device": "CI Mac mini", "os": "15.5", "build": "81", "branch": "feature", "trendStory": "volatile"]
        ),
        run(
            id: "run.volatile.baseline.2",
            suiteID: buildSuite.id,
            scenarioID: volatileScenario.id,
            startedAt: 1_776_272_800,
            archiveState: .archived,
            metadata: ["device": "CI Mac mini", "os": "15.5", "build": "82", "branch": "main", "trendStory": "volatile"]
        ),
        run(
            id: "run.volatile.current.2",
            suiteID: buildSuite.id,
            scenarioID: volatileScenario.id,
            startedAt: 1_776_359_200,
            archiveState: .archived,
            metadata: ["device": "CI Mac mini", "os": "15.5", "build": "83", "branch": "feature", "trendStory": "volatile"]
        ),
        run(
            id: "run.recovered.baseline.1",
            suiteID: buildSuite.id,
            scenarioID: recoveredScenario.id,
            startedAt: 1_776_445_600,
            archiveState: .archived,
            metadata: ["device": "CI Mac mini", "os": "15.5", "build": "84", "branch": "main", "trendStory": "recovered"]
        ),
        run(
            id: "run.recovered.baseline.2",
            suiteID: buildSuite.id,
            scenarioID: recoveredScenario.id,
            startedAt: 1_776_532_000,
            archiveState: .archived,
            metadata: ["device": "CI Mac mini", "os": "15.5", "build": "85", "branch": "main", "trendStory": "recovered"]
        ),
        run(
            id: "run.recovered.current",
            suiteID: buildSuite.id,
            scenarioID: recoveredScenario.id,
            startedAt: 1_776_618_400,
            archiveState: .archived,
            metadata: ["device": "CI Mac mini", "os": "15.5", "build": "86", "branch": "feature", "trendStory": "recovered"]
        )
    ]

    static let activeSamples: [BenchmarkSample] = [
        sample(id: "sample.latency.baseline.1", runID: "run.active.baseline", scenarioID: launchScenario.id, metricID: latencyMetric.id, value: 120, measuredAt: 1_777_700_100, tags: [baselineTag, smokeTag]),
        sample(id: "sample.latency.baseline.2", runID: "run.active.baseline", scenarioID: launchScenario.id, metricID: latencyMetric.id, value: 118, measuredAt: 1_777_700_200, tags: [baselineTag, smokeTag]),
        sample(id: "sample.latency.current.1", runID: "run.active.current", scenarioID: launchScenario.id, metricID: latencyMetric.id, value: 90, measuredAt: 1_777_786_500, tags: [currentTag, smokeTag]),
        sample(id: "sample.latency.current.2", runID: "run.active.current", scenarioID: launchScenario.id, metricID: latencyMetric.id, value: 88, measuredAt: 1_777_786_600, tags: [currentTag, smokeTag]),
        sample(id: "sample.latency.baseline.phone.1", runID: "run.active.baseline.phone", scenarioID: launchScenario.id, metricID: latencyMetric.id, value: 132, measuredAt: 1_777_700_950, tags: [baselineTag, smokeTag]),
        sample(id: "sample.latency.current.phone.1", runID: "run.active.current.phone", scenarioID: launchScenario.id, metricID: latencyMetric.id, value: 98, measuredAt: 1_777_787_350, tags: [currentTag, smokeTag]),
        sample(id: "sample.throughput.baseline.1", runID: "run.active.baseline", scenarioID: launchScenario.id, metricID: throughputMetric.id, value: 300, measuredAt: 1_777_700_100, tags: [baselineTag, smokeTag]),
        sample(id: "sample.throughput.current.1", runID: "run.active.current", scenarioID: launchScenario.id, metricID: throughputMetric.id, value: 260, measuredAt: 1_777_786_500, tags: [currentTag, smokeTag]),
        sample(id: "sample.memory.baseline.1", runID: "run.scrolling.baseline", scenarioID: scrollingScenario.id, metricID: memoryMetric.id, value: 700, measuredAt: 1_777_710_100, tags: [baselineTag, smokeTag]),
        sample(id: "sample.memory.current.1", runID: "run.scrolling.current", scenarioID: scrollingScenario.id, metricID: memoryMetric.id, value: 840, measuredAt: 1_777_796_500, tags: [currentTag, smokeTag]),
        sample(id: "sample.quality.baseline.1", runID: "run.scrolling.baseline", scenarioID: scrollingScenario.id, metricID: qualityMetric.id, value: 0.98, measuredAt: 1_777_710_100, tags: [baselineTag, smokeTag]),
        sample(id: "sample.quality.current.1", runID: "run.scrolling.current", scenarioID: scrollingScenario.id, metricID: qualityMetric.id, value: 0.96, measuredAt: 1_777_796_500, tags: [currentTag, smokeTag]),
        sample(id: "sample.payload.baseline.1", runID: "run.import.baseline", scenarioID: importScenario.id, metricID: payloadMetric.id, value: 2048, measuredAt: 1_777_720_100, tags: [baselineTag, smokeTag]),
        sample(id: "sample.cache.current.1", runID: "run.import.current", scenarioID: importScenario.id, metricID: cacheMetric.id, value: 120, measuredAt: 1_777_806_500, tags: [currentTag, smokeTag]),
        sample(id: "sample.build-time.baseline.1", runID: "run.build.baseline", scenarioID: compileScenario.id, metricID: buildTimeMetric.id, value: 64, measuredAt: 1_777_730_100, tags: [baselineTag, smokeTag]),
        sample(id: "sample.build-time.baseline.2", runID: "run.build.baseline", scenarioID: compileScenario.id, metricID: buildTimeMetric.id, value: 62, measuredAt: 1_777_730_200, tags: [baselineTag, smokeTag]),
        sample(id: "sample.build-time.current.1", runID: "run.build.current", scenarioID: compileScenario.id, metricID: buildTimeMetric.id, value: 51, measuredAt: 1_777_816_500, tags: [currentTag, smokeTag]),
        sample(id: "sample.build-time.current.2", runID: "run.build.current", scenarioID: compileScenario.id, metricID: buildTimeMetric.id, value: 53, measuredAt: 1_777_816_600, tags: [currentTag, smokeTag]),
        sample(id: "sample.export-blocking.baseline.1", runID: "run.export.baseline", scenarioID: BenchmarkExportBlocking.collageScenario.id, metricID: BenchmarkExportBlocking.perceivedBlockingDurationMetric.id, value: 4.8, measuredAt: 1_777_742_100, tags: [baselineTag, smokeTag, BenchmarkExportBlocking.exportTag]),
        sample(id: "sample.export-blocking.baseline.2", runID: "run.export.baseline", scenarioID: BenchmarkExportBlocking.collageScenario.id, metricID: BenchmarkExportBlocking.perceivedBlockingDurationMetric.id, value: 5.1, measuredAt: 1_777_742_200, tags: [baselineTag, smokeTag, BenchmarkExportBlocking.exportTag]),
        sample(id: "sample.export-blocking.current.1", runID: "run.export.current", scenarioID: BenchmarkExportBlocking.collageScenario.id, metricID: BenchmarkExportBlocking.perceivedBlockingDurationMetric.id, value: 6.4, measuredAt: 1_777_828_500, tags: [currentTag, smokeTag, BenchmarkExportBlocking.exportTag]),
        sample(id: "sample.export-blocking.current.2", runID: "run.export.current", scenarioID: BenchmarkExportBlocking.collageScenario.id, metricID: BenchmarkExportBlocking.perceivedBlockingDurationMetric.id, value: 6.6, measuredAt: 1_777_828_600, tags: [currentTag, smokeTag, BenchmarkExportBlocking.exportTag])
    ]

    static let archivedSamples: [BenchmarkSample] = [
        sample(id: "sample.archived.baseline.1", runID: "run.archived.baseline", scenarioID: archivedScenario.id, metricID: latencyMetric.id, value: 140, measuredAt: 1_776_000_100, tags: [baselineTag, smokeTag]),
        sample(id: "sample.archived.current.1", runID: "run.archived.current", scenarioID: archivedScenario.id, metricID: latencyMetric.id, value: 130, measuredAt: 1_776_086_500, tags: [currentTag, smokeTag]),
        sample(id: "sample.volatile.baseline.1", runID: "run.volatile.baseline.1", scenarioID: volatileScenario.id, metricID: buildTimeMetric.id, value: 100, measuredAt: 1_776_100_100, tags: [baselineTag, smokeTag]),
        sample(id: "sample.volatile.current.1", runID: "run.volatile.current.1", scenarioID: volatileScenario.id, metricID: buildTimeMetric.id, value: 130, measuredAt: 1_776_186_500, tags: [currentTag, smokeTag]),
        sample(id: "sample.volatile.baseline.2", runID: "run.volatile.baseline.2", scenarioID: volatileScenario.id, metricID: buildTimeMetric.id, value: 92, measuredAt: 1_776_272_900, tags: [baselineTag, smokeTag]),
        sample(id: "sample.volatile.current.2", runID: "run.volatile.current.2", scenarioID: volatileScenario.id, metricID: buildTimeMetric.id, value: 125, measuredAt: 1_776_359_300, tags: [currentTag, smokeTag]),
        sample(id: "sample.recovered.baseline.1", runID: "run.recovered.baseline.1", scenarioID: recoveredScenario.id, metricID: buildTimeMetric.id, value: 100, measuredAt: 1_776_445_700, tags: [baselineTag, smokeTag]),
        sample(id: "sample.recovered.baseline.2", runID: "run.recovered.baseline.2", scenarioID: recoveredScenario.id, metricID: buildTimeMetric.id, value: 135, measuredAt: 1_776_532_100, tags: [baselineTag, smokeTag]),
        sample(id: "sample.recovered.current", runID: "run.recovered.current", scenarioID: recoveredScenario.id, metricID: buildTimeMetric.id, value: 92, measuredAt: 1_776_618_500, tags: [currentTag, smokeTag])
    ]

    static let launchOptimizationNote = BenchmarkPerformanceChangeNote(
        id: "note.demo.launch-cache-warmup",
        area: .launch,
        changeType: .optimization,
        summary: "Cache warmup moved before first dashboard render.",
        expectedImpact: .improvesPerformance,
        affectedBenchmarks: [
            BenchmarkPerformanceChangeAffectedBenchmark(
                suiteID: renderingSuite.id,
                scenarioID: launchScenario.id,
                metricID: latencyMetric.id
            )
        ],
        risk: .medium,
        buildIntroduced: BenchmarkPerformanceChangeBuild(bundleBuildNumber: "101", bundleShortVersion: "26.5.3"),
        validationNotes: [
            "Likely related to launch latency changes; treat as a correlation signal, not proof of cause."
        ]
    )

    static let documentationOnlyNote = BenchmarkPerformanceChangeNote(
        id: "note.demo.change-note-copy",
        area: .instrumentation,
        changeType: .instrumentation,
        summary: "Clarified benchmark dashboard copy without changing measured workflows.",
        expectedImpact: .neutral,
        affectedBenchmarks: [.noBenchmarkImpact],
        risk: .low,
        buildIntroduced: BenchmarkPerformanceChangeBuild(bundleBuildNumber: "101", bundleShortVersion: "26.5.3"),
        validationNotes: [
            "No benchmark impact expected; retained as a no-impact fixture for validation."
        ]
    )

    static let exportRouteRiskNote = BenchmarkPerformanceChangeNote(
        id: "note.demo.export-route-imgly",
        area: .media,
        changeType: .dependency,
        summary: "Export route changed to IMGLY for collage video rendering.",
        expectedImpact: .regressesPerformance,
        affectedBenchmarks: [
            BenchmarkPerformanceChangeAffectedBenchmark(
                suiteID: BenchmarkExportBlocking.suite.id,
                scenarioID: BenchmarkExportBlocking.collageScenario.id,
                metricID: BenchmarkExportBlocking.perceivedBlockingDurationMetric.id,
                metadata: [
                    BenchmarkRelatedPerformanceChangeNoteMetadataKey.historyScopeName: "Current"
                ]
            )
        ],
        risk: .high,
        buildIntroduced: BenchmarkPerformanceChangeBuild(bundleBuildNumber: "4201", bundleShortVersion: "26.5.3"),
        validationNotes: [
            "May explain export-blocking movement, but benchmark deltas are not causal evidence."
        ]
    )

    static func run(
        id: BenchmarkRun.ID,
        suiteID: BenchmarkSuite.ID,
        scenarioID: BenchmarkScenario.ID,
        startedAt: TimeInterval,
        archiveState: BenchmarkArchiveState,
        metadata: [String: String],
        performanceChangeNotes: [BenchmarkPerformanceChangeNote] = []
    ) -> BenchmarkRun {
        BenchmarkRun(
            id: id,
            suiteID: suiteID,
            scenarioID: scenarioID,
            startedAt: Date(timeIntervalSince1970: startedAt),
            archiveState: archiveState,
            tags: [smokeTag],
            metadata: metadata
                .merging(envelopeMetadata(from: metadata), uniquingKeysWith: { current, _ in current }),
            envelope: performanceChangeNotes.isEmpty ? nil : BenchmarkEnvelope(
                environment: demoEnvironment(from: metadata),
                performanceChangeNotes: performanceChangeNotes
            )
        )
    }

    static func sample(
        id: BenchmarkSample.ID,
        runID: BenchmarkRun.ID,
        scenarioID: BenchmarkScenario.ID,
        metricID: BenchmarkMetric.ID,
        value: Double,
        measuredAt: TimeInterval,
        tags: Set<BenchmarkTag>
    ) -> BenchmarkSample {
        let scenario = catalog.scenario(withID: scenarioID)!

        return BenchmarkSample(
            id: id,
            runID: runID,
            suiteID: scenario.suiteID,
            scenarioID: scenarioID,
            metricID: metricID,
            value: value,
            measuredAt: Date(timeIntervalSince1970: measuredAt),
            tags: tags
        )
    }

    static func exportMetadata(
        build: String,
        branch: String,
        configuration: String,
        profile: String,
        exportRoute: String,
        samplingProfile: BenchmarkSamplingProfile,
        bundleBuildNumber: String
    ) -> [String: String] {
        let environment = BenchmarkEnvironment(
            deviceModel: "iPhone17,1",
            cpuClass: "arm64e",
            totalPhysicalMemoryBytes: 8_589_934_592,
            osVersion: "iOS 26.0",
            osBuildNumber: "23A344",
            bundleShortVersion: "26.5.3",
            bundleBuildNumber: bundleBuildNumber,
            gitSHA: "demo-audit",
            scheme: configuration,
            isSimulator: false,
            localeIdentifier: "en_US",
            timeZoneIdentifier: "America/Los_Angeles"
        )
        let shape = BenchmarkExportShapeContext(
            exportKind: .collage,
            engineRoute: exportRoute == "imgly" ? .imgly : .native,
            pageCount: 3,
            sceneItemCount: 12,
            videoItemCount: 2,
            imageItemCount: 6,
            stickerItemCount: 3,
            textItemCount: 1,
            hasAudio: true,
            outputWidth: 1080,
            outputHeight: 1920,
            outputDurationSeconds: 12.5,
            outputFrameRate: 30,
            outputContainer: .mp4,
            outputBitrateKbps: 8_000,
            samplingProfile: samplingProfile
        )

        return BenchmarkEnvelope(environment: environment).historyMetadata(merging: [
            "device": "iPhone17,1",
            "os": "26.0",
            "build": build,
            "branch": branch,
            "configuration": configuration,
            "profile": profile,
            "exportRoute": exportRoute,
            "samplingProfile": samplingProfile.rawValue,
            BenchmarkExportShapeContext.metadataKey: try! shape.encodedString()
        ])
    }

    static func demoEnvironment(from metadata: [String: String]) -> BenchmarkEnvironment {
        let bundleBuildNumber = metadata[BenchmarkEnvironmentMetadataKey.bundleBuildNumber] ??
            metadata["build"] ??
            "0"

        return BenchmarkEnvironment(
            deviceModel: metadata["device"] ?? "Simulator",
            cpuClass: "arm64e",
            totalPhysicalMemoryBytes: 8_589_934_592,
            osVersion: metadata["os"].map { "iOS \($0)" } ?? "iOS 26.0",
            osBuildNumber: "23A344",
            bundleShortVersion: "26.5.3",
            bundleBuildNumber: bundleBuildNumber,
            gitSHA: "demo-performance-notes",
            scheme: metadata["configuration"] ?? "release",
            isSimulator: metadata["device"]?.localizedCaseInsensitiveContains("Simulator") ?? false,
            localeIdentifier: "en_US",
            timeZoneIdentifier: "America/Los_Angeles"
        )
    }

    static func envelopeMetadata(from metadata: [String: String]) -> [String: String] {
        guard metadata[BenchmarkEnvironmentMetadataKey.bundleBuildNumber] == nil else {
            return [:]
        }
        guard let build = metadata["build"], build.isEmpty == false else {
            return [:]
        }
        return [BenchmarkEnvironmentMetadataKey.bundleBuildNumber: build]
    }
}
