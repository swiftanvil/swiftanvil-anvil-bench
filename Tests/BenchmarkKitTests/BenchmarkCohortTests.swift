import Foundation
import Testing
@testable import BenchmarkKit

@Suite("BenchmarkCohort")
struct BenchmarkCohortTests {
    private let suiteID: BenchmarkSuite.ID = "suite.editor"
    private let scenarioID: BenchmarkScenario.ID = "scenario.export"
    private let metricID: BenchmarkMetric.ID = "metric.duration"
    private let durationMetric = BenchmarkMetric(
        id: "metric.duration",
        name: "Duration",
        unit: .milliseconds,
        direction: .lowerIsBetter
    )

    private func envelope(
        deviceModel: String = "iPhone15,3",
        bundleBuildNumber: String = "4216",
        isSimulator: Bool = false,
        extras: [String: String] = [:]
    ) -> BenchmarkEnvelope {
        let environment = BenchmarkEnvironment(
            deviceModel: deviceModel,
            cpuClass: "arm64e",
            totalPhysicalMemoryBytes: 6 * 1024 * 1024 * 1024,
            osVersion: "18.2.0",
            osBuildNumber: "22C152",
            bundleShortVersion: "26.5.3",
            bundleBuildNumber: bundleBuildNumber,
            gitSHA: nil,
            scheme: "Debug",
            isSimulator: isSimulator,
            localeIdentifier: "en_US",
            timeZoneIdentifier: "UTC"
        )
        return BenchmarkEnvelope(environment: environment, extras: extras)
    }

    private func run(
        id: String,
        tags: Set<BenchmarkTag> = [],
        titleHash: String? = nil,
        envelope: BenchmarkEnvelope? = nil,
        startedAt: TimeInterval = 0,
        scenarioFingerprint: BenchmarkScenarioFingerprint? = nil
    ) -> BenchmarkRun {
        BenchmarkRun(
            id: BenchmarkRun.ID(id),
            suiteID: suiteID,
            scenarioID: scenarioID,
            startedAt: Date(timeIntervalSince1970: startedAt),
            tags: tags,
            envelope: envelope,
            titleHash: titleHash,
            scenarioFingerprint: scenarioFingerprint
        )
    }

    private func sample(
        id: String,
        runID: BenchmarkRun.ID,
        value: Double,
        measuredAt: TimeInterval
    ) -> BenchmarkSample {
        BenchmarkSample(
            id: BenchmarkSample.ID(id),
            runID: runID,
            suiteID: suiteID,
            scenarioID: scenarioID,
            metricID: metricID,
            value: value,
            measuredAt: Date(timeIntervalSince1970: measuredAt)
        )
    }

    @Test("Cohort filter AND-combines clauses")
    func cohortFilterCombinesClauses() {
        let cohort = BenchmarkCohort(
            id: "cohort.warm-export",
            name: "Warm exports",
            filter: BenchmarkCohortFilter(
                requiredTagIDs: ["action.filter.warmLUT"],
                titleHashes: ["hash-a"],
                envelopeFacets: [.deviceModel: ["iPhone15,3"]]
            )
        )

        let match = run(
            id: "r1",
            tags: ["action.filter.warmLUT"],
            titleHash: "hash-a",
            envelope: envelope()
        )
        let wrongHash = run(
            id: "r2",
            tags: ["action.filter.warmLUT"],
            titleHash: "hash-b",
            envelope: envelope()
        )
        let wrongDevice = run(
            id: "r3",
            tags: ["action.filter.warmLUT"],
            titleHash: "hash-a",
            envelope: envelope(deviceModel: "iPhone14,2")
        )
        let missingTag = run(
            id: "r4",
            tags: [],
            titleHash: "hash-a",
            envelope: envelope()
        )

        #expect(cohort.contains(match))
        #expect(!cohort.contains(wrongHash))
        #expect(!cohort.contains(wrongDevice))
        #expect(!cohort.contains(missingTag))
    }

    @Test("Empty filter matches every run")
    func emptyFilterMatchesEveryRun() {
        let cohort = BenchmarkCohort(id: "cohort.all", name: "All", filter: BenchmarkCohortFilter())
        #expect(cohort.contains(run(id: "r1")))
        #expect(cohort.contains(run(id: "r2", envelope: envelope())))
    }

    @Test("Excluded tags reject runs that carry them")
    func excludedTagsRejectRuns() {
        let cohort = BenchmarkCohort(
            id: "cohort.no-ai",
            name: "Without AI Enhance",
            filter: BenchmarkCohortFilter(excludedTagIDs: ["action.filter.aiEnhance"])
        )
        #expect(cohort.contains(run(id: "r1", tags: ["action.filter.warmLUT"])))
        #expect(!cohort.contains(run(id: "r2", tags: ["action.filter.aiEnhance"])))
    }

    @Test("Cohort save → load → query round-trips identical run sets")
    func cohortRoundTripsAcrossEncode() async throws {
        let warmTag: BenchmarkTag = "action.filter.warmLUT"
        let coolTag: BenchmarkTag = "action.filter.coolLUT"

        let envelopeMatch = envelope(extras: ["experiment.warmTone": "on"])
        let envelopeMiss = envelope(extras: ["experiment.warmTone": "off"])

        let runs: [BenchmarkRun] = [
            run(id: "match-1", tags: [warmTag], titleHash: "hash-a", envelope: envelopeMatch),
            run(id: "match-2", tags: [warmTag], titleHash: "hash-a", envelope: envelopeMatch),
            run(id: "wrong-tag", tags: [coolTag], titleHash: "hash-a", envelope: envelopeMatch),
            run(id: "wrong-hash", tags: [warmTag], titleHash: "hash-b", envelope: envelopeMatch),
            run(id: "wrong-extra", tags: [warmTag], titleHash: "hash-a", envelope: envelopeMiss)
        ]
        let snapshot = BenchmarkHistorySnapshot(runs: runs)

        let cohort = BenchmarkCohort(
            id: "cohort.warm-export",
            name: "Warm exports",
            filter: BenchmarkCohortFilter(
                requiredTagIDs: [warmTag.id],
                titleHashes: ["hash-a"],
                envelopeFacets: ["experiment.warmTone": ["on"]]
            )
        )

        let encoded = try BenchmarkCohortFilter.encoder.encode(cohort)
        let reloaded = try BenchmarkCohortFilter.decoder.decode(BenchmarkCohort.self, from: encoded)
        #expect(reloaded == cohort)

        let firstRun = try await snapshot.runs(in: reloaded).map(\.id.rawValue).sorted()
        let secondRun = try await snapshot.runs(in: reloaded).map(\.id.rawValue).sorted()
        #expect(firstRun == ["match-1", "match-2"])
        #expect(firstRun == secondRun)
    }

    @Test("Grouping preserves cohort order and lets runs appear in multiple cohorts")
    func groupingProducesPerCohortRuns() async throws {
        let warmTag: BenchmarkTag = "action.filter.warmLUT"
        let exportTag: BenchmarkTag = "action.export.h264_1080p"

        let runs: [BenchmarkRun] = [
            run(id: "warm-only", tags: [warmTag]),
            run(id: "export-only", tags: [exportTag]),
            run(id: "both", tags: [warmTag, exportTag])
        ]
        let snapshot = BenchmarkHistorySnapshot(runs: runs)

        let warm = BenchmarkCohort(
            id: "cohort.warm",
            name: "Warm",
            filter: BenchmarkCohortFilter(requiredTagIDs: [warmTag.id])
        )
        let export = BenchmarkCohort(
            id: "cohort.export",
            name: "Export",
            filter: BenchmarkCohortFilter(requiredTagIDs: [exportTag.id])
        )

        let grouped = try await snapshot.runs(grouping: [warm, export])
        #expect(grouped.map(\.cohort.id) == [warm.id, export.id])
        #expect(Set(grouped[0].runs.map(\.id.rawValue)) == ["warm-only", "both"])
        #expect(Set(grouped[1].runs.map(\.id.rawValue)) == ["export-only", "both"])
    }

    @Test("Nearest comparable lookup accepts close fuzzy matches and rejects distant fingerprints")
    func nearestComparableLookupAcceptsCloseFuzzyMatchesAndRejectsDistantFingerprints() async throws {
        let closeFingerprint = fingerprint(workflow: "collage-ingest", mediaKind: "video", mediaBucket: "short-video")
        let distantBucket = fingerprint(workflow: "collage-ingest", mediaKind: "video", mediaBucket: "long-video")
        let distantGate = fingerprint(workflow: "draft-load", mediaKind: "video", mediaBucket: "short-video")
        let reference = run(id: "reference", startedAt: 40, scenarioFingerprint: closeFingerprint)
        let snapshot = BenchmarkHistorySnapshot(runs: [
            run(id: "older-close", startedAt: 10, scenarioFingerprint: closeFingerprint),
            run(id: "nearest-close", startedAt: 20, scenarioFingerprint: closeFingerprint),
            run(id: "distant-bucket", startedAt: 30, scenarioFingerprint: distantBucket),
            run(id: "distant-gate", startedAt: 35, scenarioFingerprint: distantGate),
            run(id: "missing-fingerprint", startedAt: 38),
            run(id: "same-time", startedAt: 40, scenarioFingerprint: closeFingerprint),
            reference
        ])

        let match = try await snapshot.nearestPreviousComparableRun(before: reference)
        let missingReference = try await snapshot.nearestPreviousComparableRun(before: run(
            id: "missing-reference",
            startedAt: 50
        ))

        #expect(match?.id.rawValue == "nearest-close")
        #expect(missingReference == nil)
    }

    @Test("Trend evaluator classifies required multi-build history shapes")
    func trendEvaluatorClassifiesRequiredHistoryShapes() {
        let cases: [(
            name: String,
            values: [Double],
            classification: BenchmarkTrendClassification,
            confidence: BenchmarkTrendConfidence,
            outcomes: Set<BenchmarkTrendHistoryOutcome>
        )] = [
            ("improving", [140, 130, 120, 100, 90], .improving, .high, []),
            ("regressing", [90, 95, 110, 120, 130], .regressing, .high, []),
            ("stable", [100, 101, 102, 101, 102], .stable, .high, [.suppressedSmallMovement]),
            ("volatile", [100, 130, 95, 125, 135], .volatile, .medium, [.noisyHistory]),
            ("missing baseline", [100], .missingBaseline, .unavailable, [.sparseHistory]),
            ("recovered", [100, 130, 95, 125, 90], .recovered, .medium, [.noisyHistory])
        ]

        for testCase in cases {
            let evaluation = trendEvaluation(values: testCase.values)

            #expect(
                evaluation.classification == testCase.classification,
                "Unexpected classification for \(testCase.name)"
            )
            #expect(evaluation.confidence == testCase.confidence, "Unexpected confidence for \(testCase.name)")
            #expect(evaluation.outcomes == testCase.outcomes, "Unexpected outcomes for \(testCase.name)")
            #expect(evaluation.lastRuns.map(\.summary.mean) == testCase.values.map(Optional.some))
        }
    }

    @Test("Trend evaluator flags sparse and noisy histories")
    func trendEvaluatorFlagsSparseAndNoisyHistories() {
        let sparse = trendEvaluation(values: [100, 115, 130])
        let noisy = trendEvaluation(values: [100, 130, 95, 125, 135])

        #expect(sparse.classification == .regressing)
        #expect(sparse.hasSparseHistory)
        #expect(sparse.hasNoisyHistory == false)
        #expect(sparse.confidence == .low)
        #expect(noisy.classification == .volatile)
        #expect(noisy.hasSparseHistory == false)
        #expect(noisy.hasNoisyHistory)
        #expect(noisy.confidence == .medium)
    }

    @Test("Comparable grouping keeps only exact envelope-backed run groups")
    func comparableGroupingKeepsOnlyExactEnvelopeBackedRunGroups() async throws {
        let referenceFingerprint = fingerprint(
            workflow: "collage-export",
            mediaKind: "video",
            mediaBucket: "short-video"
        )
        let otherFingerprint = fingerprint(workflow: "collage-export", mediaKind: "video", mediaBucket: "long-video")
        let samePrevious = comparableRun(id: "same-previous", startedAt: 10, fingerprint: referenceFingerprint)
        let current = comparableRun(id: "current", startedAt: 50, fingerprint: referenceFingerprint)
        let otherBuild = comparableRun(
            id: "other-build",
            startedAt: 40,
            bundleBuildNumber: "4217",
            fingerprint: referenceFingerprint
        )
        let otherDevice = comparableRun(
            id: "other-device",
            startedAt: 30,
            deviceModel: "iPhone14,2",
            fingerprint: referenceFingerprint
        )
        let otherShape = comparableRun(id: "other-shape", startedAt: 20, fingerprint: otherFingerprint)
        let missingEnvelope = run(id: "missing-envelope", startedAt: 5, scenarioFingerprint: referenceFingerprint)
        let runs = [samePrevious, current, otherBuild, otherDevice, otherShape, missingEnvelope]
        let samples = [
            sample(id: "same-previous-sample", runID: samePrevious.id, value: 120, measuredAt: 11),
            sample(id: "current-sample", runID: current.id, value: 90, measuredAt: 51),
            sample(id: "other-build-sample", runID: otherBuild.id, value: 10, measuredAt: 41),
            sample(id: "other-device-sample", runID: otherDevice.id, value: 10, measuredAt: 31),
            sample(id: "other-shape-sample", runID: otherShape.id, value: 10, measuredAt: 21),
            sample(id: "missing-envelope-sample", runID: missingEnvelope.id, value: 10, measuredAt: 6)
        ]
        let source = BenchmarkHistorySnapshot(runs: runs)
        let groups = try await source.comparableRunGroups()
        let currentGroup = try #require(groups.first { group in
            group.runs.contains { $0.id == current.id }
        })
        let evaluation = BenchmarkTrendEvaluator().evaluation(
            for: durationMetric,
            currentRun: current,
            historyRuns: runs,
            samples: samples
        )

        #expect(currentGroup.runs.map(\.id.rawValue) == ["current", "same-previous"])
        #expect(groups.flatMap(\.runs).contains { $0.id == missingEnvelope.id } == false)
        #expect(evaluation.previousComparable?.run.id == samePrevious.id)
        #expect(evaluation.lastRuns.map(\.run.id.rawValue) == ["same-previous", "current"])
        #expect(evaluation.classification == .improving)
    }

    @Test("Run title override survives Codable round-trip and coexists with the hash")
    func runTitleOverrideRoundTrips() throws {
        var run = run(id: "regression-1", tags: ["action.export.h264_1080p"], titleHash: "hash-known-regression")
        run.titleOverride = "Known regression: warm LUT export"

        let data = try JSONEncoder().encode(run)
        let decoded = try JSONDecoder().decode(BenchmarkRun.self, from: data)
        #expect(decoded.titleOverride == "Known regression: warm LUT export")
        #expect(decoded.titleHash == "hash-known-regression")
        #expect(decoded == run)
    }

    @Test("Pre-titled runs decode with nil title fields for backward compatibility")
    func legacyRunsDecodeWithoutTitleFields() throws {
        let legacyJSON = """
        {
            "id": "legacy-1",
            "suiteID": "suite.editor",
            "scenarioID": "scenario.export",
            "startedAt": 0,
            "archiveState": "active",
            "tags": [],
            "metadata": {}
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(BenchmarkRun.self, from: legacyJSON)
        #expect(decoded.titleOverride == nil)
        #expect(decoded.titleHash == nil)
        #expect(decoded.envelope == nil)
    }

    private func fingerprint(
        workflow: String,
        mediaKind: String,
        mediaBucket: String
    ) -> BenchmarkScenarioFingerprint {
        BenchmarkScenarioFingerprint(
            strictGates: BenchmarkScenarioStrictGates([
                "workflow.family": workflow,
                "media.kind": mediaKind
            ]),
            fuzzyBucket: BenchmarkScenarioFuzzyBucket([
                "media.bucket": mediaBucket
            ])
        )
    }

    private func comparableRun(
        id: String,
        startedAt: TimeInterval,
        bundleBuildNumber: String = "4216",
        deviceModel: String = "iPhone15,3",
        fingerprint: BenchmarkScenarioFingerprint
    ) -> BenchmarkRun {
        run(
            id: id,
            envelope: envelope(deviceModel: deviceModel, bundleBuildNumber: bundleBuildNumber),
            startedAt: startedAt,
            scenarioFingerprint: fingerprint
        )
    }

    private func trendEvaluation(values: [Double]) -> BenchmarkTrendEvaluation {
        let scenarioFingerprint = fingerprint(
            workflow: "collage-export",
            mediaKind: "video",
            mediaBucket: "short-video"
        )
        let runs = values.enumerated().map { index, _ in
            run(
                id: "trend-\(index)",
                startedAt: TimeInterval(index + 1),
                scenarioFingerprint: scenarioFingerprint
            )
        }
        let samples = zip(runs, values).map { run, value in
            sample(
                id: "\(run.id.rawValue)-sample",
                runID: run.id,
                value: value,
                measuredAt: run.startedAt.timeIntervalSince1970 + 0.5
            )
        }
        let currentRun = runs[runs.count - 1]

        return BenchmarkTrendEvaluator().evaluation(
            for: durationMetric,
            currentRun: currentRun,
            historyRuns: runs,
            samples: samples
        )
    }
}
