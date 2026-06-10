import AnvilCore
import Foundation
import Testing
@testable import BenchmarkKit

@Suite("BenchmarkKit primitives")
struct BenchmarkKitTests {
    @Test("Identities are type-scoped and codable")
    func identitiesAreTypeScopedAndCodable() throws {
        let suite = BenchmarkSuite(
            id: "suite.zap-list",
            name: "Zap List",
            tags: ["active"],
            metadata: ["owner": "benchmarking"]
        )
        let scenario = BenchmarkScenario(
            id: "scenario.scroll",
            suiteID: suite.id,
            name: "Scroll"
        )

        let encodedSuite = try JSONEncoder().encode(suite)
        let decodedSuite = try JSONDecoder().decode(BenchmarkSuite.self, from: encodedSuite)

        #expect(decodedSuite == suite)
        #expect(scenario.suiteID == suite.id)
        #expect(BenchmarkSuite.ID("suite.zap-list").rawValue == "suite.zap-list")
        #expect(Set([suite.id, BenchmarkSuite.ID("suite.zap-list")]).count == 1)
    }

    @Test("Queries preserve identity, date, tag, and archive filters")
    func queriesPreserveFilterInputs() {
        let smokeTag = BenchmarkTag(id: "smoke")
        let dateRange = BenchmarkDateRange(
            from: Date(timeIntervalSince1970: 10),
            through: Date(timeIntervalSince1970: 20)
        )
        let runQuery = BenchmarkRunQuery(
            suiteIDs: [Fixture.suiteID],
            scenarioIDs: [Fixture.scenarioID],
            tagIDs: [smokeTag.id],
            archiveFilter: .active,
            startedAt: dateRange,
            limit: 5,
            sortOrder: .ascending
        )
        let activeRun = Fixture.run(
            id: "active-run",
            startedAt: 12,
            archiveState: .active,
            tags: [smokeTag]
        )
        let archivedRun = Fixture.run(
            id: "archived-run",
            startedAt: 12,
            archiveState: .archived,
            tags: [smokeTag]
        )
        let untaggedRun = Fixture.run(id: "untagged-run", startedAt: 12)

        #expect(runQuery.archiveFilter.archiveStates == [.active])
        #expect(runQuery.limit == 5)
        #expect(runQuery.sortOrder == .ascending)
        #expect(runQuery.matches(activeRun))
        #expect(!runQuery.matches(archivedRun))
        #expect(!runQuery.matches(untaggedRun))

        let sampleQuery = BenchmarkSampleQuery(
            runIDs: ["archived-run"],
            suiteIDs: [Fixture.suiteID],
            scenarioIDs: [Fixture.scenarioID],
            metricIDs: [Fixture.metricID],
            tagIDs: [smokeTag.id],
            runArchiveFilter: .archived,
            measuredAt: dateRange,
            limit: 2,
            sortOrder: .descending
        )

        #expect(sampleQuery.runArchiveFilter.archiveStates == [.archived])
        #expect(sampleQuery.limit == 2)
        #expect(sampleQuery.sortOrder == .descending)
    }

    @Test("History data source loads runs and samples by active and archived queries")
    func historyDataSourceLoadsByQuery() async throws {
        let activeRun = Fixture.run(id: "active-run", startedAt: 10, archiveState: .active)
        let archivedRun = Fixture.run(id: "archived-run", startedAt: 20, archiveState: .archived)
        let activeSample = Fixture.sample(id: "active-sample", runID: activeRun.id, value: 10, measuredAt: 11)
        let archivedSample = Fixture.sample(id: "archived-sample", runID: archivedRun.id, value: 20, measuredAt: 21)
        let source = BenchmarkHistorySnapshot(
            runs: [activeRun, archivedRun],
            samples: [activeSample, archivedSample]
        )

        let activeRuns = try await source.runs(matching: BenchmarkRunQuery(archiveFilter: .active))
        let archivedSamples = try await source.samples(
            matching: BenchmarkSampleQuery(
                metricIDs: [Fixture.metricID],
                runArchiveFilter: .archived
            )
        )

        #expect(activeRuns.map(\.id) == [activeRun.id])
        #expect(archivedSamples.map(\.id) == [archivedSample.id])
    }

    @Test("Comparison builder computes baseline-current deltas and trend summaries")
    func comparisonBuilderComputesDeltasAndTrends() throws {
        let builder = BenchmarkComparisonBuilder(metric: Fixture.latencyMetric)
        let comparison = builder.makeComparison(
            baseline: [
                Fixture.sample(id: "baseline-1", value: 100, measuredAt: 1),
                Fixture.sample(id: "baseline-2", value: 120, measuredAt: 2)
            ],
            current: [
                Fixture.sample(id: "current-1", value: 80, measuredAt: 3),
                Fixture.sample(id: "current-2", value: 90, measuredAt: 4)
            ]
        )
        let delta = try #require(comparison.delta)
        let currentMean = try #require(comparison.current.mean)
        let percentage = try #require(delta.percentage)
        let trend = builder.makeTrendSummary(from: [
            Fixture.sample(id: "trend-1", value: 120, measuredAt: 1),
            Fixture.sample(id: "trend-2", value: 100, measuredAt: 2),
            Fixture.sample(id: "trend-3", value: 80, measuredAt: 3)
        ])

        #expect(comparison.dataState == .complete)
        #expect(comparison.baseline.count == 2)
        #expect(currentMean == 85)
        #expect(delta.absolute == -25)
        #expect(abs(percentage - -22.7272727) < 0.0001)
        #expect(comparison.trend.direction == .improved)
        #expect(trend.direction == .improved)
        #expect(trend.sampleCount == 3)
    }

    @Test("Comparison builder reports missing data states")
    func comparisonBuilderReportsMissingData() {
        let builder = BenchmarkComparisonBuilder(metric: Fixture.latencyMetric)
        let missingBaseline = builder.makeComparison(
            baseline: [],
            current: [Fixture.sample(id: "current-only", value: 80, measuredAt: 1)]
        )
        let missingCurrent = builder.makeComparison(
            baseline: [Fixture.sample(id: "baseline-only", value: 100, measuredAt: 1)],
            current: []
        )
        let missingBoth = builder.makeComparison(baseline: [], current: [])

        #expect(missingBaseline.dataState == .missingBaseline)
        #expect(missingBaseline.delta == nil)
        #expect(missingBaseline.trend.direction == .unavailable)
        #expect(missingCurrent.dataState == .missingCurrent)
        #expect(missingBoth.dataState == .missingBaselineAndCurrent)
    }

    @Test("Insight evaluator applies thresholds and suppresses noisy or missing-baseline results")
    func insightEvaluatorAppliesThresholdsAndSuppressesNoisyOrMissingBaselineResults() throws {
        let evaluator = BenchmarkInsightEvaluator(
            policy: BenchmarkInsightEvaluationPolicy(
                minimumSamplesPerSide: 2,
                minimumAbsolutePercentageChange: 10,
                minimumAbsoluteDelta: 5
            )
        )
        let builder = BenchmarkComparisonBuilder(metric: Fixture.latencyMetric)
        let visibleRegression = builder.makeComparison(
            baseline: [
                Fixture.sample(id: "baseline-1", value: 100, measuredAt: 1),
                Fixture.sample(id: "baseline-2", value: 100, measuredAt: 2),
                Fixture.sample(id: "ignored-noise", metricID: "throughput", value: 10000, measuredAt: 3)
            ],
            current: [
                Fixture.sample(id: "current-1", value: 116, measuredAt: 4),
                Fixture.sample(id: "current-2", value: 116, measuredAt: 5),
                Fixture.sample(id: "ignored-current-noise", metricID: "throughput", value: 1, measuredAt: 6)
            ]
        )
        let belowPercentageThreshold = builder.makeComparison(
            baseline: [
                Fixture.sample(id: "small-baseline-1", value: 100, measuredAt: 1),
                Fixture.sample(id: "small-baseline-2", value: 100, measuredAt: 2)
            ],
            current: [
                Fixture.sample(id: "small-current-1", value: 109, measuredAt: 3),
                Fixture.sample(id: "small-current-2", value: 109, measuredAt: 4)
            ]
        )
        let noisySingleSample = builder.makeComparison(
            baseline: [Fixture.sample(id: "single-baseline", value: 100, measuredAt: 1)],
            current: [Fixture.sample(id: "single-current", value: 140, measuredAt: 2)]
        )
        let missingBaseline = builder.makeComparison(
            baseline: [],
            current: [
                Fixture.sample(id: "missing-baseline-current-1", value: 140, measuredAt: 1),
                Fixture.sample(id: "missing-baseline-current-2", value: 140, measuredAt: 2)
            ]
        )

        let insight = try #require(evaluator.visibleInsight(for: visibleRegression))
        let regressionDelta = try #require(visibleRegression.delta)

        #expect(visibleRegression.baseline.count == 2)
        #expect(visibleRegression.current.count == 2)
        #expect(regressionDelta.absolute == 16)
        #expect(insight.kind == .regression)
        #expect(insight.title == "Latency regression versus baseline")
        #expect(evaluator.visibleInsight(for: belowPercentageThreshold) == nil)
        #expect(evaluator.visibleInsight(for: noisySingleSample) == nil)
        #expect(evaluator.visibleInsight(for: missingBaseline) == nil)
    }

    @Test("Performance change notes parse and validate benchmark impact declarations")
    func performanceChangeNotesParseAndValidateBenchmarkImpactDeclarations() throws {
        let json = """
        {
          "notes": [
            {
              "id": "note.valid",
              "area": "launch",
              "changeType": "optimization",
              "summary": "Prewarm launch cache before first render.",
              "expectedImpact": "improvesPerformance",
              "affectedBenchmarks": [
                {
                  "suiteID": "suite",
                  "scenarioID": "scenario",
                  "metricID": "latency",
                  "metadata": {}
                }
              ],
              "risk": "medium",
              "buildIntroduced": {
                "bundleBuildNumber": "101",
                "bundleShortVersion": "26.5.3",
                "sourceRevision": null,
                "metadata": {}
              },
              "validationNotes": [
                "May explain movement; correlation signal only, not proof of cause."
              ],
              "metadata": {}
            }
          ]
        }
        """
        let data = try #require(json.data(using: .utf8))
        let bundle = try BenchmarkPerformanceChangeNoteBundle(jsonData: data)
        let validNote = try #require(bundle.notes.first)
        let registry = BenchmarkIDRegistry(
            suites: [BenchmarkSuite(id: Fixture.suiteID, name: "Suite")],
            scenarios: [BenchmarkScenario(id: Fixture.scenarioID, suiteID: Fixture.suiteID, name: "Scenario")],
            metrics: [Fixture.latencyMetric]
        )
        let invalidNote = Fixture.performanceChangeNote(
            id: "note.invalid",
            affectedBenchmarks: [
                BenchmarkPerformanceChangeAffectedBenchmark(
                    suiteID: "suite.missing",
                    scenarioID: "scenario.missing",
                    metricID: "metric.missing"
                )
            ]
        )
        let noImpactNote = Fixture.performanceChangeNote(
            id: "note.no-impact",
            affectedBenchmarks: [.noBenchmarkImpact],
            expectedImpact: .neutral
        )
        let conflictingNote = Fixture.performanceChangeNote(
            id: "note.conflicting",
            affectedBenchmarks: [
                .noBenchmarkImpact,
                BenchmarkPerformanceChangeAffectedBenchmark(metricID: Fixture.metricID)
            ]
        )

        let validValidation = registry.validate(validNote)
        let invalidValidation = registry.validate(invalidNote)
        let noImpactValidation = registry.validate(noImpactNote)
        let conflictingValidation = registry.validate(conflictingNote)

        #expect(validNote.id == "note.valid")
        #expect(validNote.affectedBenchmarks.first?.metricID == Fixture.metricID)
        #expect(validValidation.isValid)
        #expect(validValidation.hasBenchmarkReferences)
        #expect(validValidation.declaresNoBenchmarkImpact == false)
        #expect(invalidValidation.isValid == false)
        #expect(invalidValidation.invalidBenchmarkIDs.map(\.kind) == [.suite, .scenario, .metric])
        #expect(noImpactValidation.isValid)
        #expect(noImpactValidation.declaresNoBenchmarkImpact)
        #expect(noImpactValidation.hasBenchmarkReferences == false)
        #expect(conflictingValidation.isValid == false)
        #expect(conflictingValidation.hasConflictingBenchmarkImpactDeclaration)
    }

    @Test("Related performance change note query matches benchmark facets and uncertainty copy")
    func relatedPerformanceChangeNoteQueryMatchesBenchmarkFacetsAndUncertaintyCopy() throws {
        let exactFingerprint = BenchmarkScenarioFingerprint(
            strictGates: BenchmarkScenarioStrictGates([
                .workflow: "collage-export",
                .mediaKind: "video"
            ]),
            fuzzyBucket: BenchmarkScenarioFuzzyBucket([
                .durationBucket: "short"
            ])
        )
        let workflowFingerprint = BenchmarkScenarioFingerprint(
            strictGates: BenchmarkScenarioStrictGates([
                .workflow: "collage-export",
                .mediaKind: "video"
            ]),
            fuzzyBucket: BenchmarkScenarioFuzzyBucket([
                .durationBucket: "long"
            ])
        )
        let unrelatedFingerprint = BenchmarkScenarioFingerprint(
            strictGates: BenchmarkScenarioStrictGates([
                .workflow: "feed-scroll",
                .mediaKind: "image"
            ]),
            fuzzyBucket: BenchmarkScenarioFuzzyBucket([
                .durationBucket: "short"
            ])
        )
        let exactNote = Fixture.performanceChangeNote(
            id: "note.exact",
            affectedBenchmarks: [
                BenchmarkPerformanceChangeAffectedBenchmark(
                    suiteID: Fixture.suiteID,
                    scenarioID: Fixture.scenarioID,
                    metricID: Fixture.metricID,
                    scenarioFingerprint: exactFingerprint,
                    metadata: [
                        BenchmarkRelatedPerformanceChangeNoteMetadataKey.historyScopeName: "Current"
                    ]
                )
            ],
            buildIntroduced: BenchmarkPerformanceChangeBuild(bundleBuildNumber: "101"),
            validationNotes: [
                "May be related to the observed change; this is not proof of cause."
            ]
        )
        let workflowNote = Fixture.performanceChangeNote(
            id: "note.workflow",
            affectedBenchmarks: [
                BenchmarkPerformanceChangeAffectedBenchmark(scenarioFingerprint: workflowFingerprint)
            ],
            buildIntroduced: BenchmarkPerformanceChangeBuild(bundleBuildNumber: "100")
        )
        let unrelatedNote = Fixture.performanceChangeNote(
            id: "note.unrelated",
            affectedBenchmarks: [
                BenchmarkPerformanceChangeAffectedBenchmark(scenarioFingerprint: unrelatedFingerprint)
            ],
            buildIntroduced: BenchmarkPerformanceChangeBuild(bundleBuildNumber: "101")
        )
        let query = BenchmarkRelatedPerformanceChangeNoteQuery(
            suiteID: Fixture.suiteID,
            scenarioID: Fixture.scenarioID,
            metricID: Fixture.metricID,
            scenarioFingerprint: exactFingerprint,
            historyScopeName: "Current",
            referenceBuildNumber: "102",
            maximumBuildDistance: 2
        )
        let exactMatch = try #require(query.match(for: exactNote))
        let workflowMatch = try #require(query.match(for: workflowNote))
        let uncertaintyCopy = exactNote.validationNotes.joined(separator: " ").lowercased()
        let exactScopes: Set<BenchmarkRelatedPerformanceChangeNoteScope> = [
            .suite,
            .scenario,
            .metric,
            .scenarioFingerprint,
            .historyScope
        ]
        let workflowScopes: Set<BenchmarkRelatedPerformanceChangeNoteScope> = [.workflowFamily]

        #expect(exactMatch.matchedScopes == exactScopes)
        #expect(exactMatch.buildDistance == 1)
        #expect(workflowMatch.matchedScopes == workflowScopes)
        #expect(workflowMatch.buildDistance == 2)
        #expect(query.match(for: unrelatedNote) == nil)
        #expect(uncertaintyCopy.contains("may"))
        #expect(uncertaintyCopy.contains("not proof"))
        #expect(uncertaintyCopy.contains("cause"))
    }

    @Test("Scenario presentation and comparison dimensions remain generic")
    func scenarioPresentationAndComparisonDimensionsRemainGeneric() {
        let comparisonDimension = BenchmarkComparisonDimension(
            id: "dimension.device",
            title: "Device",
            kind: .singleKey,
            visibility: .both,
            keys: ["device"]
        )
        let scenario = BenchmarkScenario(
            id: "scenario.presentation",
            suiteID: Fixture.suiteID,
            name: "Presentation",
            presentation: BenchmarkScenarioPresentation(
                primaryMetricID: Fixture.metricID,
                metricOrder: [Fixture.metricID],
                comparisonDimensionIDs: [comparisonDimension.id]
            )
        )
        let catalog = BenchmarkDashboardCatalog(
            suites: [BenchmarkSuite(id: Fixture.suiteID, name: "Suite")],
            scenarios: [scenario],
            metrics: [Fixture.latencyMetric],
            comparisonDimensions: [comparisonDimension]
        )

        #expect(catalog.comparisonDimensions(for: scenario.id).map(\.id) == [comparisonDimension.id])
        #expect(scenario.presentation?.primaryMetricID == Fixture.metricID)
        #expect(scenario.presentation?.metricOrder == [Fixture.metricID])
    }

    @Test("No-op and test implementations satisfy recorder and measurer contracts")
    func recorderAndMeasurerImplementationsAreCompatible() async throws {
        let runDescriptor = BenchmarkRunDescriptor(
            suiteID: Fixture.suiteID,
            scenarioID: Fixture.scenarioID,
            startedAt: Date(timeIntervalSince1970: 1)
        )
        let sampleDescriptor = BenchmarkSampleDescriptor(
            suiteID: Fixture.suiteID,
            scenarioID: Fixture.scenarioID,
            metricID: Fixture.metricID,
            value: 42,
            measuredAt: Date(timeIntervalSince1970: 2)
        )
        let noOpRecorder: any BenchmarkRecorder = NoOpBenchmarkRecorder()
        let noOpRun = try await noOpRecorder.startRun(runDescriptor)
        let noOpSample = try await noOpRecorder.recordSample(sampleDescriptor, in: noOpRun.id)

        #expect(noOpRun.id == "noop-run")
        #expect(noOpSample.id == "noop-sample")
        #expect(noOpSample.runID == noOpRun.id)
        try await noOpRecorder.finishRun(
            id: noOpRun.id,
            endedAt: Date(timeIntervalSince1970: 3)
        )

        let testRecorder = CapturingBenchmarkRecorder()
        let recordedRun = try await testRecorder.startRun(runDescriptor)
        let recordedSample = try await testRecorder.recordSample(sampleDescriptor, in: recordedRun.id)
        try await testRecorder.finishRun(
            id: recordedRun.id,
            endedAt: Date(timeIntervalSince1970: 3)
        )

        #expect(recordedSample.value == 42)
        #expect(await testRecorder.runCount == 1)
        #expect(await testRecorder.sampleCount == 1)
        #expect(await testRecorder.finishedRunIDs == [recordedRun.id])

        let measurer: any BenchmarkMeasuring = NoOpBenchmarkMeasurer()
        let measurement = try await measurer.measure {
            "measured"
        }

        #expect(measurement.value == "measured")
        #expect(measurement.elapsedSeconds == 0)
    }

    @Test("BenchmarkTaskRunner returns AnvilTask with BenchmarkResult")
    func benchmarkTaskRunnerReturnsAnvilTask() async throws {
        let runner = BenchmarkTaskRunner(recorder: NoOpBenchmarkRecorder(), measurer: NoOpBenchmarkMeasurer())
        let descriptor = BenchmarkRunDescriptor(
            suiteID: Fixture.suiteID,
            scenarioID: Fixture.scenarioID
        )

        let task = try await runner.run(descriptor: descriptor) {
            [
                BenchmarkSampleDescriptor(
                    suiteID: Fixture.suiteID,
                    scenarioID: Fixture.scenarioID,
                    metricID: Fixture.metricID,
                    value: 100
                )
            ]
        }

        #expect(!task.id.uuidString.isEmpty)
        #expect(task.label.contains("benchmark-"))

        let result = try await task.value
        #expect(result.run.suiteID == Fixture.suiteID)
        #expect(result.run.scenarioID == Fixture.scenarioID)
        #expect(result.samples.count == 1)
        #expect(result.samples[0].value == 100)
    }

    @Test("BenchmarkTaskRunner uses WallClockBenchmarkMeasurer by default")
    func benchmarkTaskRunnerUsesWallClock() async throws {
        let runner = BenchmarkTaskRunner(recorder: NoOpBenchmarkRecorder())
        let descriptor = BenchmarkRunDescriptor(
            suiteID: Fixture.suiteID,
            scenarioID: Fixture.scenarioID
        )

        let task = try await runner.run(descriptor: descriptor) {
            []
        }

        let result = try await task.value
        #expect(result.elapsedSeconds >= 0)
    }
}

private enum Fixture {
    static let suiteID = BenchmarkSuite.ID("suite")
    static let scenarioID = BenchmarkScenario.ID("scenario")
    static let metricID = BenchmarkMetric.ID("latency")
    static let latencyMetric = BenchmarkMetric(
        id: metricID,
        name: "Latency",
        unit: .milliseconds,
        direction: .lowerIsBetter
    )

    static func performanceChangeNote(
        id: BenchmarkPerformanceChangeNote.ID,
        affectedBenchmarks: [BenchmarkPerformanceChangeAffectedBenchmark],
        expectedImpact: BenchmarkPerformanceExpectedImpact = .unknown,
        buildIntroduced: BenchmarkPerformanceChangeBuild = BenchmarkPerformanceChangeBuild(bundleBuildNumber: "101"),
        validationNotes: [String] = []
    ) -> BenchmarkPerformanceChangeNote {
        BenchmarkPerformanceChangeNote(
            id: id,
            area: .launch,
            changeType: .optimization,
            summary: "Benchmark-affecting change.",
            expectedImpact: expectedImpact,
            affectedBenchmarks: affectedBenchmarks,
            risk: .medium,
            buildIntroduced: buildIntroduced,
            validationNotes: validationNotes
        )
    }

    static func run(
        id: BenchmarkRun.ID,
        startedAt: TimeInterval,
        archiveState: BenchmarkArchiveState = .active,
        tags: Set<BenchmarkTag> = []
    ) -> BenchmarkRun {
        BenchmarkRun(
            id: id,
            suiteID: suiteID,
            scenarioID: scenarioID,
            startedAt: Date(timeIntervalSince1970: startedAt),
            archiveState: archiveState,
            tags: tags
        )
    }

    static func sample(
        id: BenchmarkSample.ID,
        runID: BenchmarkRun.ID = "run",
        metricID: BenchmarkMetric.ID = Fixture.metricID,
        value: Double,
        measuredAt: TimeInterval,
        tags: Set<BenchmarkTag> = []
    ) -> BenchmarkSample {
        BenchmarkSample(
            id: id,
            runID: runID,
            suiteID: suiteID,
            scenarioID: scenarioID,
            metricID: metricID,
            value: value,
            measuredAt: Date(timeIntervalSince1970: measuredAt),
            tags: tags
        )
    }
}

private actor CapturingBenchmarkRecorder: BenchmarkRecorder {
    private var runs: [BenchmarkRun] = []
    private var samples: [BenchmarkSample] = []
    private var finishedRuns: [BenchmarkRun.ID] = []

    var runCount: Int {
        runs.count
    }

    var sampleCount: Int {
        samples.count
    }

    var finishedRunIDs: [BenchmarkRun.ID] {
        finishedRuns
    }

    func startRun(_ descriptor: BenchmarkRunDescriptor) async throws -> BenchmarkRun {
        let run = BenchmarkRun(
            id: BenchmarkRun.ID("test-run-\(runs.count + 1)"),
            suiteID: descriptor.suiteID,
            scenarioID: descriptor.scenarioID,
            startedAt: descriptor.startedAt,
            archiveState: descriptor.archiveState,
            tags: descriptor.tags,
            metadata: descriptor.metadata
        )
        runs.append(run)
        return run
    }

    func recordSample(
        _ descriptor: BenchmarkSampleDescriptor,
        in runID: BenchmarkRun.ID
    ) async throws -> BenchmarkSample {
        let sample = BenchmarkSample(
            id: BenchmarkSample.ID("test-sample-\(samples.count + 1)"),
            runID: runID,
            suiteID: descriptor.suiteID,
            scenarioID: descriptor.scenarioID,
            metricID: descriptor.metricID,
            value: descriptor.value,
            measuredAt: descriptor.measuredAt,
            tags: descriptor.tags,
            metadata: descriptor.metadata
        )
        samples.append(sample)
        return sample
    }

    func finishRun(id: BenchmarkRun.ID, endedAt _: Date) async throws {
        finishedRuns.append(id)
    }
}
