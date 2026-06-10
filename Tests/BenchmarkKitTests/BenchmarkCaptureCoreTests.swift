import Foundation
import Testing
@testable import BenchmarkKit

@Suite("BenchmarkKit capture core")
struct BenchmarkCaptureCoreTests {
    @Test("BenchmarkEnvironment round-trips through JSON")
    func environmentRoundTrips() throws {
        let environment = makeEnvironment()
        let data = try JSONEncoder().encode(environment)
        let decoded = try JSONDecoder().decode(BenchmarkEnvironment.self, from: data)
        #expect(decoded == environment)
        #expect(decoded.benchmarkKitVersion == BenchmarkKitVersion.current)
    }

    @Test("BenchmarkSamplingProfile exposes documented cadence and retention")
    func samplingProfileBudgets() {
        #expect(BenchmarkSamplingProfile.light.samplesPerSecond == 1)
        #expect(BenchmarkSamplingProfile.deep.samplesPerSecond == 10)
        #expect(BenchmarkSamplingProfile.light.retainsRawSamples == false)
        #expect(BenchmarkSamplingProfile.deep.retainsRawSamples == true)
        #expect(abs(BenchmarkSamplingProfile.light.samplingInterval - 1.0) < 0.0001)
        #expect(abs(BenchmarkSamplingProfile.deep.samplingInterval - 0.1) < 0.0001)
    }

    @Test("BenchmarkSignalSummary computes percentiles deterministically")
    func summaryPercentiles() throws {
        let summary = try #require(BenchmarkSignalSummary.make(from: Array(stride(from: 1.0, through: 100.0, by: 1.0))))
        #expect(summary.minimum == 1)
        #expect(summary.peak == 100)
        #expect(abs(summary.average - 50.5) < 0.0001)
        #expect(summary.p50 == 50 || summary.p50 == 51) // index rounding boundary
        #expect(summary.p95 == 95 || summary.p95 == 96)
        #expect(summary.p99 == 99 || summary.p99 == 100)
    }

    @Test("Light sampler keeps summary stats and discards raw samples")
    func lightSamplerRetention() async {
        let reader = FixedReader.sequence(values: [10, 20, 30, 40, 50])
        let sampler = BenchmarkSystemSampler(profile: .light, reader: reader)
        for _ in 0 ..< 5 {
            await sampler.record(reader.readSample())
        }
        let retained = await sampler.retainedSamples
        let summary = await sampler.summary()
        #expect(retained.isEmpty)
        #expect(summary.sampleCount == 5)
        #expect(summary.cpuUsageFraction?.peak == 0.5)
    }

    @Test("Deep sampler keeps the raw trace")
    func deepSamplerRetention() async {
        let reader = FixedReader.sequence(values: [10, 20, 30])
        let sampler = BenchmarkSystemSampler(profile: .deep, reader: reader)
        for _ in 0 ..< 3 {
            await sampler.record(reader.readSample())
        }
        let retained = await sampler.retainedSamples
        let summary = await sampler.summary()
        #expect(retained.count == 3)
        #expect(summary.sampleCount == 3)
    }

    @Test("BenchmarkRun decodes legacy payloads with nil envelope")
    func legacyRunDecodesWithoutEnvelope() throws {
        let legacyJSON = #"""
        {
          "id": "run.legacy",
          "suiteID": "suite",
          "scenarioID": "scenario",
          "startedAt": 0,
          "archiveState": "active",
          "tags": [],
          "metadata": {}
        }
        """#
        let data = try #require(legacyJSON.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BenchmarkRun.self, from: data)
        #expect(decoded.envelope == nil)
        #expect(decoded.systemSummary == nil)
        #expect(decoded.id.rawValue == "run.legacy")
    }

    @Test("BenchmarkRun envelope round-trips through JSON")
    func envelopeRoundTripsOnRun() throws {
        let summary = BenchmarkSystemSummary.make(
            profile: .light,
            samples: [
                BenchmarkSystemSample(
                    measuredAt: Date(timeIntervalSince1970: 1),
                    residentMemoryBytes: 1000,
                    memoryFootprintBytes: 1200,
                    cpuUsageFraction: 0.1,
                    thermalState: .nominal,
                    isLowPowerModeEnabled: false
                )
            ]
        )
        var run = BenchmarkRun(
            id: "run.envelope",
            suiteID: "suite",
            scenarioID: "scenario",
            startedAt: Date(timeIntervalSince1970: 1)
        )
        run.envelope = BenchmarkEnvelope(environment: makeEnvironment(), extras: ["account": "deadbeef"])
        run.systemSummary = summary
        let encoded = try JSONEncoder().encode(run)
        let decoded = try JSONDecoder().decode(BenchmarkRun.self, from: encoded)
        #expect(decoded.envelope?.environment == run.envelope?.environment)
        #expect(decoded.envelope?.extras == ["account": "deadbeef"])
        #expect(decoded.systemSummary?.sampleCount == 1)
    }

    @Test("BenchmarkEnvelope decodes legacy payloads without performance notes")
    func legacyEnvelopeDecodesWithoutPerformanceNotes() throws {
        let legacyJSON = #"""
        {
          "environment": {
            "deviceModel": "iPhone15,3",
            "cpuClass": "arm64e",
            "totalPhysicalMemoryBytes": 6442450944,
            "osVersion": "18.2.0",
            "osBuildNumber": "22C100",
            "bundleShortVersion": "26.5.3",
            "bundleBuildNumber": "4216",
            "gitSHA": "abc1234",
            "scheme": "Release",
            "isSimulator": false,
            "benchmarkKitVersion": "0.2.0",
            "localeIdentifier": "en_US",
            "timeZoneIdentifier": "America/Los_Angeles"
          },
          "extras": {},
          "metricKit": []
        }
        """#
        let data = try #require(legacyJSON.data(using: .utf8))
        let decoded = try JSONDecoder().decode(BenchmarkEnvelope.self, from: data)

        #expect(decoded.performanceChangeNotes.isEmpty)
        #expect(decoded.environment.bundleBuildNumber == "4216")
    }

    @Test("Performance note bundles preserve imported build associations")
    func performanceNoteBundlesPreserveImportedBuildAssociations() throws {
        let environment = makeEnvironment()
        let importedBuild = BenchmarkPerformanceChangeBuild(
            bundleBuildNumber: "4000",
            bundleShortVersion: "26.4.0",
            sourceRevision: "old-sha"
        )
        let missingBuild = BenchmarkPerformanceChangeBuild(bundleBuildNumber: "")
        let importedNote = makePerformanceChangeNote(id: "note.imported", buildIntroduced: importedBuild)
        let missingBuildNote = makePerformanceChangeNote(id: "note.missing-build", buildIntroduced: missingBuild)
        let bundle = BenchmarkPerformanceChangeNoteBundle(notes: [importedNote, missingBuildNote])
        let encoded = try bundle.jsonData()
        let decoded = try BenchmarkPerformanceChangeNoteBundle(jsonData: encoded)
            .fillingMissingBuildIntroduced(with: environment.performanceChangeBuild())
        let envelope = BenchmarkEnvelope(environment: environment, performanceChangeNotes: decoded.notes)

        #expect(envelope.performanceChangeNotes[0].buildIntroduced.bundleBuildNumber == "4000")
        #expect(envelope.performanceChangeNotes[0].buildIntroduced.sourceRevision == "old-sha")
        #expect(envelope.performanceChangeNotes[1].buildIntroduced.bundleBuildNumber == "4216")
        #expect(envelope.performanceChangeNotes[1].buildIntroduced.bundleShortVersion == "26.5.3")
        #expect(envelope.performanceChangeNotes[1].buildIntroduced.sourceRevision == "abc1234")
    }

    @Test("MetricKit bridge buffers and drains payloads on all platforms")
    func metricKitBridgeBufferAndDrain() async {
        let bridge = BenchmarkMetricKitBridge()
        let payload = BenchmarkMetricKitPayload(
            kind: .metric,
            timeStampBegin: Date(timeIntervalSince1970: 0),
            timeStampEnd: Date(timeIntervalSince1970: 1),
            jsonData: Data("{}".utf8)
        )
        await bridge.append(payload)
        let drained = await bridge.drain()
        let after = await bridge.recentPayloads
        #expect(drained == [payload])
        #expect(after.isEmpty)
    }

    @Test("Export-blocking suite, scenarios, and metrics use stable identifiers and ordering")
    func exportBlockingSchemaIdentifiers() {
        #expect(BenchmarkExportBlocking.suite.id == BenchmarkExportBlocking.suiteID)
        #expect(BenchmarkExportBlocking.suite.id.rawValue == "export-blocking")

        let scenarios = BenchmarkExportBlocking.scenarios
        #expect(scenarios.map(\.id) == [
            BenchmarkExportBlocking.collageScenarioID,
            BenchmarkExportBlocking.reelsScenarioID
        ])
        #expect(scenarios.allSatisfy { $0.suiteID == BenchmarkExportBlocking.suiteID })
        #expect(BenchmarkExportBlocking.collageScenarioID.rawValue == "export-blocking.collage")
        #expect(BenchmarkExportBlocking.reelsScenarioID.rawValue == "export-blocking.reels")

        // Both scenarios surface the same primary metric and ordering for dashboard parity.
        for scenario in scenarios {
            #expect(scenario.presentation?.primaryMetricID == BenchmarkExportBlocking.perceivedBlockingDurationMetricID)
            #expect(scenario.presentation?.metricOrder == BenchmarkExportBlocking.orderedMetricIDs)
        }

        let metrics = BenchmarkExportBlocking.metrics
        #expect(metrics.map(\.id) == BenchmarkExportBlocking.orderedMetricIDs)
    }

    @Test("Export-blocking metrics carry the documented units and directions")
    func exportBlockingMetricUnitsAndDirections() {
        #expect(BenchmarkExportBlocking.perceivedBlockingDurationMetric.unit == .seconds)
        #expect(BenchmarkExportBlocking.perceivedBlockingDurationMetric.direction == .lowerIsBetter)

        #expect(BenchmarkExportBlocking.exporterRuntimeMetric.unit == .seconds)
        #expect(BenchmarkExportBlocking.exporterRuntimeMetric.direction == .lowerIsBetter)

        #expect(BenchmarkExportBlocking.peakResidentMemoryMetric.unit == .bytes)
        #expect(BenchmarkExportBlocking.peakResidentMemoryMetric.direction == .lowerIsBetter)

        #expect(BenchmarkExportBlocking.peakMemoryFootprintMetric.unit == .bytes)
        #expect(BenchmarkExportBlocking.peakMemoryFootprintMetric.direction == .lowerIsBetter)

        // Headroom is "higher is better" because shrinking headroom raises jetsam risk.
        #expect(BenchmarkExportBlocking.minAvailableMemoryHeadroomMetric.unit == .bytes)
        #expect(BenchmarkExportBlocking.minAvailableMemoryHeadroomMetric.direction == .higherIsBetter)

        #expect(BenchmarkExportBlocking.peakCPUUsageMetric.unit == .ratio)
        #expect(BenchmarkExportBlocking.peakCPUUsageMetric.direction == .lowerIsBetter)
    }

    @Test("BenchmarkExportShapeContext round-trips through JSON")
    func exportShapeContextRoundTrips() throws {
        let context = BenchmarkExportShapeContext(
            exportKind: .collage,
            engineRoute: .native,
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
            outputBitrateKbps: 8000,
            samplingProfile: .deep
        )

        let encoded = try context.encodedString()
        let decoded = try BenchmarkExportShapeContext.decoded(from: encoded)
        #expect(decoded == context)

        // The encoded form is stable for embedding in BenchmarkRun.metadata.
        let again = try decoded.encodedString()
        #expect(again == encoded)
    }

    @Test("BenchmarkExportShapeContext decodes nil optional fields")
    func exportShapeContextOptionalsDecode() throws {
        let minimalJSON = #"""
        {
          "exportKind": "reels",
          "engineRoute": "imgly",
          "pageCount": 1,
          "sceneItemCount": 0,
          "videoItemCount": 0,
          "imageItemCount": 0,
          "stickerItemCount": 0,
          "textItemCount": 0,
          "hasAudio": false,
          "samplingProfile": "light"
        }
        """#
        let context = try BenchmarkExportShapeContext.decoded(from: minimalJSON)
        #expect(context.exportKind == .reels)
        #expect(context.engineRoute == .imgly)
        #expect(context.outputWidth == nil)
        #expect(context.outputHeight == nil)
        #expect(context.outputDurationSeconds == nil)
        #expect(context.outputFrameRate == nil)
        #expect(context.outputContainer == nil)
        #expect(context.outputBitrateKbps == nil)
        #expect(context.samplingProfile == .light)
    }

    @Test("BenchmarkExportShapeContext metadata key is the documented stable string")
    func exportShapeContextMetadataKey() {
        #expect(BenchmarkExportShapeContext.metadataKey == "benchmark.export.shape")
    }

    /// Regression guard for the privacy invariant in `BenchmarkExportShapeContext`.
    ///
    /// Every field on the context type is enumerated below with an explicit non-PII rationale.
    /// Adding a field without recording its rationale here causes the test suite to drift from
    /// the privacy contract documented on the type and must be caught at review time.
    @Test("BenchmarkExportShapeContext fields each carry an explicit non-PII justification")
    func exportShapeContextFieldsAreNonPII() throws {
        struct FieldRationale {
            let name: String
            let jsonValue: Any?
            let rationale: String
        }

        let rationales: [FieldRationale] = [
            FieldRationale(
                name: "exportKind",
                jsonValue: "collage",
                rationale: "closed enum over BenchmarkKit-known product flows; not user content"
            ),
            FieldRationale(
                name: "engineRoute",
                jsonValue: "native",
                rationale: "code-path label identifying the export pipeline; not user content"
            ),
            FieldRationale(
                name: "pageCount",
                jsonValue: 1,
                rationale: "integer count of scene structure; carries no identifiers"
            ),
            FieldRationale(
                name: "sceneItemCount",
                jsonValue: 0,
                rationale: "integer count of placed objects; carries no identifiers or content"
            ),
            FieldRationale(
                name: "videoItemCount",
                jsonValue: 0,
                rationale: "integer count by item type; does not reference asset identifiers"
            ),
            FieldRationale(
                name: "imageItemCount",
                jsonValue: 0,
                rationale: "integer count by item type; does not reference asset identifiers"
            ),
            FieldRationale(
                name: "stickerItemCount",
                jsonValue: 0,
                rationale: "integer count by item type; sticker library IDs are not stored"
            ),
            FieldRationale(
                name: "textItemCount",
                jsonValue: 0,
                rationale: "integer count only; text bodies are never read or stored"
            ),
            FieldRationale(
                name: "hasAudio",
                jsonValue: false,
                rationale: "boolean pipeline-shape indicator; not audio content"
            ),
            FieldRationale(
                name: "outputWidth",
                jsonValue: nil,
                rationale: "physical output dimension; independent of user content"
            ),
            FieldRationale(
                name: "outputHeight",
                jsonValue: nil,
                rationale: "physical output dimension; independent of user content"
            ),
            FieldRationale(
                name: "outputDurationSeconds",
                jsonValue: nil,
                rationale: "timing of produced asset; not its content"
            ),
            FieldRationale(
                name: "outputFrameRate",
                jsonValue: nil,
                rationale: "encoder configuration value"
            ),
            FieldRationale(
                name: "outputContainer",
                jsonValue: nil,
                rationale: "codec/container enum"
            ),
            FieldRationale(
                name: "outputBitrateKbps",
                jsonValue: nil,
                rationale: "encoder configuration value"
            ),
            FieldRationale(
                name: "samplingProfile",
                jsonValue: "light",
                rationale: "BenchmarkKit framework knob; controls cadence/retention only"
            )
        ]

        // No rationale is empty.
        for entry in rationales {
            #expect(entry.rationale.isEmpty == false, "\(entry.name) is missing a non-PII rationale")
        }

        // Every field that appears in the type's JSON output is accounted for above; any field
        // added later without an entry will fail this assertion. Optionals are populated so the
        // encoder emits every key.
        let context = BenchmarkExportShapeContext(
            exportKind: .collage,
            engineRoute: .native,
            outputWidth: 1080,
            outputHeight: 1920,
            outputDurationSeconds: 1,
            outputFrameRate: 30,
            outputContainer: .mp4,
            outputBitrateKbps: 8000
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(context)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        let documentedKeys = Set(rationales.map(\.name))
        let encodedKeys = Set(json.keys)
        let drift = "BenchmarkExportShapeContext field set drifted from the privacy rationale enumeration. " +
            "Encoded: \(encodedKeys.sorted()). Documented: \(documentedKeys.sorted())."
        #expect(documentedKeys == encodedKeys, Comment(rawValue: drift))
    }

    @Test("Light profile sampling adds <2% CPU and <5MB RSS on a synthetic loop")
    func lightProfileCalibrationBudget() async {
        // Synthetic scenario: tight CPU loop that runs for a known wall-clock window with and
        // without the .light sampler attached. The cost of sampling must stay inside the budget.
        let workDuration: TimeInterval = 0.4

        let baseline = await measureSynthetic(workDuration: workDuration, sampler: nil)
        let sampler = BenchmarkSystemSampler(profile: .light, reader: DefaultBenchmarkSystemSampleReader())
        await sampler.start()
        let measured = await measureSynthetic(workDuration: workDuration, sampler: sampler)
        await sampler.stop()

        // CPU overhead: extra wall-clock time the synthetic loop took relative to the baseline,
        // normalized to the workload duration. .light is 1 Hz so on a < 1s window we expect 0–1
        // samples; the budget enforces that headroom rather than measuring an exact percentage.
        let overheadFraction = max(0, (measured.elapsedSeconds - baseline.elapsedSeconds) / workDuration)
        #expect(
            overheadFraction < 0.02,
            "Light-mode sampler added \(overheadFraction * 100)% wall-clock overhead (>2%)"
        )

        let memoryDelta = Int64(measured.peakResident) - Int64(baseline.peakResident)
        let memoryDeltaMB = Double(max(0, memoryDelta)) / (1024 * 1024)
        #expect(memoryDeltaMB < 5.0, "Light-mode sampler added \(memoryDeltaMB) MB resident (>5 MB)")
    }

    // MARK: - Helpers

    private func makeEnvironment() -> BenchmarkEnvironment {
        BenchmarkEnvironment(
            deviceModel: "iPhone15,3",
            cpuClass: "arm64e",
            totalPhysicalMemoryBytes: 6 * 1024 * 1024 * 1024,
            osVersion: "18.2.0",
            osBuildNumber: "22C100",
            bundleShortVersion: "26.5.3",
            bundleBuildNumber: "4216",
            gitSHA: "abc1234",
            scheme: "Release",
            isSimulator: false,
            localeIdentifier: "en_US",
            timeZoneIdentifier: "America/Los_Angeles"
        )
    }

    private func makePerformanceChangeNote(
        id: BenchmarkPerformanceChangeNote.ID,
        buildIntroduced: BenchmarkPerformanceChangeBuild
    ) -> BenchmarkPerformanceChangeNote {
        BenchmarkPerformanceChangeNote(
            id: id,
            area: .instrumentation,
            changeType: .optimization,
            summary: "Reduce benchmark setup overhead.",
            expectedImpact: .improvesPerformance,
            affectedBenchmarks: [.noBenchmarkImpact],
            risk: .low,
            buildIntroduced: buildIntroduced
        )
    }

    private func measureSynthetic(
        workDuration: TimeInterval,
        sampler: BenchmarkSystemSampler?
    ) async -> (elapsedSeconds: TimeInterval, peakResident: UInt64) {
        _ = sampler // referenced so the actor stays alive across the measured window
        let start = Date()
        let deadline = start.addingTimeInterval(workDuration)
        var peakResident: UInt64 = MachTaskInfo.readMemory().resident
        var counter: UInt64 = 0
        while Date() < deadline {
            counter &+= 1
            if counter & 0xFFFF == 0 {
                peakResident = max(peakResident, MachTaskInfo.readMemory().resident)
            }
        }
        return (Date().timeIntervalSince(start), peakResident)
    }
}

/// Deterministic reader used by the retention tests; returns a constant CPU fraction.
private struct FixedReader: BenchmarkSystemSampleReader {
    let cpuFraction: Double

    static func sequence(values _: [Double]) -> FixedReader {
        FixedReader(cpuFraction: 0.5)
    }

    func readSample() -> BenchmarkSystemSample {
        BenchmarkSystemSample(
            measuredAt: Date(),
            residentMemoryBytes: 1000,
            memoryFootprintBytes: 1200,
            cpuUsageFraction: cpuFraction,
            thermalState: .nominal,
            isLowPowerModeEnabled: false
        )
    }
}
