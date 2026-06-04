import Foundation

// MARK: - Export blocking schema

/// Scenario, metric, and context definitions for the perceived export-blocking benchmark chain.
///
/// This namespace provides the *schema only*: identifiers, display names, units, and ordering
/// hints for the collage and reels export flows. Sampler adapters, persistence wiring, and
/// instrumentation live in sibling files; they reference these constants so producer and
/// consumer code agree on a single stable identifier set.
///
/// The schema is intentionally additive — it does not modify `BenchmarkRun`, `BenchmarkSample`,
/// or other core models. Consumers compose runs against `BenchmarkExportBlocking.scenarios` and
/// emit samples against `BenchmarkExportBlocking.metrics` exactly like any other suite.
public enum BenchmarkExportBlocking {
    // MARK: Identifiers

    /// Stable identifier for the export-blocking suite. Persisted across runs and devices.
    public static let suiteID: BenchmarkSuite.ID = "export-blocking"

    /// Stable identifier for the collage-export scenario inside the export-blocking suite.
    public static let collageScenarioID: BenchmarkScenario.ID = "export-blocking.collage"

    /// Stable identifier for the reels-export scenario inside the export-blocking suite.
    public static let reelsScenarioID: BenchmarkScenario.ID = "export-blocking.reels"

    /// Stable identifier for the perceived-blocking-duration metric (action-to-terminal-result).
    public static let perceivedBlockingDurationMetricID: BenchmarkMetric.ID =
        "export-blocking.perceived-blocking-duration"

    /// Stable identifier for the exporter-runtime metric (pure exporter duration, no UI gating).
    public static let exporterRuntimeMetricID: BenchmarkMetric.ID =
        "export-blocking.exporter-runtime"

    /// Stable identifier for the peak resident-memory metric sampled across the blocking window.
    public static let peakResidentMemoryMetricID: BenchmarkMetric.ID =
        "export-blocking.peak-resident-memory-bytes"

    /// Stable identifier for the peak `phys_footprint`-based memory metric.
    public static let peakMemoryFootprintMetricID: BenchmarkMetric.ID =
        "export-blocking.peak-memory-footprint-bytes"

    /// Stable identifier for the minimum available-memory headroom observed during the run.
    public static let minAvailableMemoryHeadroomMetricID: BenchmarkMetric.ID =
        "export-blocking.min-available-memory-headroom-bytes"

    /// Stable identifier for the peak CPU usage fraction observed during the run.
    public static let peakCPUUsageMetricID: BenchmarkMetric.ID =
        "export-blocking.peak-cpu-usage-fraction"

    // MARK: Tags

    /// Tag applied to every artifact produced by this suite.
    public static let exportTag = BenchmarkTag(id: "export")

    /// Tag applied to scenarios that measure perceived blocking duration on the main flow.
    public static let blockingTag = BenchmarkTag(id: "blocking")

    /// Tag applied to the collage-export scenario.
    public static let collageTag = BenchmarkTag(id: "collage")

    /// Tag applied to the reels-export scenario.
    public static let reelsTag = BenchmarkTag(id: "reels")

    // MARK: Suite

    /// The export-blocking suite that owns the collage and reels scenarios.
    public static let suite = BenchmarkSuite(
        id: suiteID,
        name: "Export Blocking",
        tags: [exportTag, blockingTag]
    )

    // MARK: Metrics

    /// Wall-clock interval between the user-visible export action and the terminal result
    /// surfaced back to the UI. Higher values represent worse perceived performance.
    public static let perceivedBlockingDurationMetric = BenchmarkMetric(
        id: perceivedBlockingDurationMetricID,
        name: "Perceived Blocking Duration",
        unit: .seconds,
        direction: .lowerIsBetter,
        tags: [exportTag, blockingTag]
    )

    /// Wall-clock interval the underlying exporter spent producing the output, independent of
    /// any framing UI. Useful for separating exporter cost from gating overhead.
    public static let exporterRuntimeMetric = BenchmarkMetric(
        id: exporterRuntimeMetricID,
        name: "Exporter Runtime",
        unit: .seconds,
        direction: .lowerIsBetter,
        tags: [exportTag]
    )

    /// Peak resident-memory bytes observed by the system sampler during the run.
    public static let peakResidentMemoryMetric = BenchmarkMetric(
        id: peakResidentMemoryMetricID,
        name: "Peak Resident Memory",
        unit: .bytes,
        direction: .lowerIsBetter,
        tags: [exportTag]
    )

    /// Peak `phys_footprint`-based memory bytes observed by the system sampler during the run.
    public static let peakMemoryFootprintMetric = BenchmarkMetric(
        id: peakMemoryFootprintMetricID,
        name: "Peak Memory Footprint",
        unit: .bytes,
        direction: .lowerIsBetter,
        tags: [exportTag]
    )

    /// Minimum bytes of remaining memory headroom observed; smaller values indicate higher
    /// jetsam risk so this metric is `.higherIsBetter`.
    public static let minAvailableMemoryHeadroomMetric = BenchmarkMetric(
        id: minAvailableMemoryHeadroomMetricID,
        name: "Minimum Available Memory Headroom",
        unit: .bytes,
        direction: .higherIsBetter,
        tags: [exportTag]
    )

    /// Peak CPU usage as a `0...1` fraction across the sampling window.
    public static let peakCPUUsageMetric = BenchmarkMetric(
        id: peakCPUUsageMetricID,
        name: "Peak CPU Usage",
        unit: .ratio,
        direction: .lowerIsBetter,
        tags: [exportTag]
    )

    /// The canonical metric ordering surfaced by dashboards and exports for this suite.
    public static let orderedMetricIDs: [BenchmarkMetric.ID] = [
        perceivedBlockingDurationMetricID,
        exporterRuntimeMetricID,
        peakResidentMemoryMetricID,
        peakMemoryFootprintMetricID,
        minAvailableMemoryHeadroomMetricID,
        peakCPUUsageMetricID
    ]

    /// Every metric defined by this suite.
    public static let metrics: [BenchmarkMetric] = [
        perceivedBlockingDurationMetric,
        exporterRuntimeMetric,
        peakResidentMemoryMetric,
        peakMemoryFootprintMetric,
        minAvailableMemoryHeadroomMetric,
        peakCPUUsageMetric
    ]

    // MARK: Scenarios

    /// Scenario describing the collage-creation export flow.
    public static let collageScenario = BenchmarkScenario(
        id: collageScenarioID,
        suiteID: suiteID,
        name: "Collage Export",
        tags: [exportTag, blockingTag, collageTag],
        presentation: BenchmarkScenarioPresentation(
            primaryMetricID: perceivedBlockingDurationMetricID,
            metricOrder: orderedMetricIDs
        )
    )

    /// Scenario describing the reels-export flow.
    public static let reelsScenario = BenchmarkScenario(
        id: reelsScenarioID,
        suiteID: suiteID,
        name: "Reels Export",
        tags: [exportTag, blockingTag, reelsTag],
        presentation: BenchmarkScenarioPresentation(
            primaryMetricID: perceivedBlockingDurationMetricID,
            metricOrder: orderedMetricIDs
        )
    )

    /// Every scenario defined by this suite.
    public static let scenarios: [BenchmarkScenario] = [collageScenario, reelsScenario]
}

// MARK: - Export shape context

/// A non-PII description of the scene and output configuration measured by an export-blocking
/// benchmark run.
///
/// ## Privacy policy
///
/// Every field is a count, dimension, codec/route enum, or sampling profile. The type **never**
/// stores user-authored text, media URLs, asset identifiers, captions, account IDs, or anything
/// that could re-identify a user or their content. Any new field MUST keep this property and
/// MUST carry a doc comment that explicitly justifies why it is non-PII; the
/// `BenchmarkExportShapeContextTests` enumeration is the regression target that locks the
/// invariant.
///
/// ## Usage
///
/// The context is intended for embedding inside `BenchmarkRun.metadata` via
/// ``BenchmarkExportShapeContext/metadataKey`` and ``BenchmarkExportShapeContext/encodedString()``.
/// Decoding round-trips through `JSONDecoder` are safe because the type is fully `Codable`.
public struct BenchmarkExportShapeContext: Hashable, Codable, Sendable {
    /// Which product flow the snapshot was captured from.
    ///
    /// *Non-PII*: closed enumeration over BenchmarkKit-known product flows; does not encode any
    /// user content.
    public enum ExportKind: String, CaseIterable, Codable, Sendable {
        /// A collage export, including single-page collages and multi-page templates.
        case collage
        /// A reels export.
        case reels
    }

    /// The export code path that produced the output.
    ///
    /// *Non-PII*: identifies the engine route the platform chose; carries no user content.
    public enum EngineRoute: String, CaseIterable, Codable, Sendable {
        /// The native AVFoundation/CoreImage export pipeline.
        case native
        /// The IMGLY/CE.SDK export pipeline.
        case imgly
        /// A hybrid pipeline that combines native and IMGLY stages.
        case hybrid
    }

    /// The container/codec family for the exporter's output file.
    ///
    /// *Non-PII*: closed enumeration over supported output formats.
    public enum OutputContainer: String, CaseIterable, Codable, Sendable {
        case mp4
        case mov
        case jpeg
        case png
        case heic
    }

    /// Which product flow the snapshot was captured from.
    ///
    /// *Non-PII justification*: closed enum over a product-defined set; not derived from user
    /// content.
    public var exportKind: ExportKind

    /// Whether the export ran on the native exporter, the IMGLY fallback, or hybrid routing.
    ///
    /// *Non-PII justification*: code-path label.
    public var engineRoute: EngineRoute

    /// Number of pages in a collage scene (`1` for single-page collages or reels).
    ///
    /// *Non-PII justification*: integer count of scene structure, not derived from user content.
    public var pageCount: Int

    /// Total number of placed scene items at export time across all pages.
    ///
    /// *Non-PII justification*: integer count of placed objects; does not include identifiers or
    /// content.
    public var sceneItemCount: Int

    /// Number of video items present in the scene.
    ///
    /// *Non-PII justification*: integer count by item type; does not reference asset identifiers
    /// or URLs.
    public var videoItemCount: Int

    /// Number of still-image items present in the scene.
    ///
    /// *Non-PII justification*: integer count by item type; does not reference asset identifiers
    /// or URLs.
    public var imageItemCount: Int

    /// Number of sticker items present in the scene.
    ///
    /// *Non-PII justification*: integer count by item type; sticker IDs/library entries are not
    /// stored.
    public var stickerItemCount: Int

    /// Number of text items present in the scene.
    ///
    /// *Non-PII justification*: integer count only — the text bodies themselves are never read
    /// or stored.
    public var textItemCount: Int

    /// Whether the export carries an audio track.
    ///
    /// *Non-PII justification*: boolean indicator of pipeline shape, not audio content.
    public var hasAudio: Bool

    /// Output canvas width in pixels (`nil` for shapes that don't expose a fixed canvas).
    ///
    /// *Non-PII justification*: physical dimension of the output frame; independent of user
    /// content.
    public var outputWidth: Int?

    /// Output canvas height in pixels.
    ///
    /// *Non-PII justification*: physical dimension of the output frame; independent of user
    /// content.
    public var outputHeight: Int?

    /// Output duration in seconds for video exports.
    ///
    /// *Non-PII justification*: timing of the produced asset, not its content.
    public var outputDurationSeconds: Double?

    /// Output frame rate in frames per second for video exports.
    ///
    /// *Non-PII justification*: encoder configuration value.
    public var outputFrameRate: Double?

    /// Output container/format produced by the exporter.
    ///
    /// *Non-PII justification*: codec/container enum.
    public var outputContainer: OutputContainer?

    /// Target output bitrate in kilobits per second when explicitly configured.
    ///
    /// *Non-PII justification*: encoder configuration value.
    public var outputBitrateKbps: Int?

    /// Sampling profile selected for the system sampler during the run.
    ///
    /// *Non-PII justification*: BenchmarkKit framework knob — controls cadence/retention only.
    public var samplingProfile: BenchmarkSamplingProfile

    /// Creates an export-shape context value.
    public init(
        exportKind: ExportKind,
        engineRoute: EngineRoute,
        pageCount: Int = 1,
        sceneItemCount: Int = 0,
        videoItemCount: Int = 0,
        imageItemCount: Int = 0,
        stickerItemCount: Int = 0,
        textItemCount: Int = 0,
        hasAudio: Bool = false,
        outputWidth: Int? = nil,
        outputHeight: Int? = nil,
        outputDurationSeconds: Double? = nil,
        outputFrameRate: Double? = nil,
        outputContainer: OutputContainer? = nil,
        outputBitrateKbps: Int? = nil,
        samplingProfile: BenchmarkSamplingProfile = .light
    ) {
        self.exportKind = exportKind
        self.engineRoute = engineRoute
        self.pageCount = pageCount
        self.sceneItemCount = sceneItemCount
        self.videoItemCount = videoItemCount
        self.imageItemCount = imageItemCount
        self.stickerItemCount = stickerItemCount
        self.textItemCount = textItemCount
        self.hasAudio = hasAudio
        self.outputWidth = outputWidth
        self.outputHeight = outputHeight
        self.outputDurationSeconds = outputDurationSeconds
        self.outputFrameRate = outputFrameRate
        self.outputContainer = outputContainer
        self.outputBitrateKbps = outputBitrateKbps
        self.samplingProfile = samplingProfile
    }
}

extension BenchmarkExportShapeContext {
    /// The stable metadata key used to embed the JSON-encoded context inside a
    /// `BenchmarkRun.metadata` dictionary.
    public static let metadataKey: String = "benchmark.export.shape"

    /// Encodes the context as a stable, sorted-keys JSON string suitable for storage in
    /// `BenchmarkRun.metadata`.
    public func encodedString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(decoding: data, as: UTF8.self)
    }

    /// Decodes a context previously serialized via ``encodedString()``.
    public static func decoded(from string: String) throws -> BenchmarkExportShapeContext {
        let data = Data(string.utf8)
        return try JSONDecoder().decode(BenchmarkExportShapeContext.self, from: data)
    }
}
