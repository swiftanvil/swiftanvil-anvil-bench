import Foundation
#if canImport(UIKit)
    import UIKit
#endif

/// The BenchmarkKit semantic version embedded into envelopes for cross-build comparability.
public enum BenchmarkKitVersion {
    /// The current BenchmarkKit version string.
    public static let current: String = "0.2.0"
}

/// A structured description of the device, OS, and build that produced a benchmark run.
public struct BenchmarkEnvironment: Hashable, Codable, Sendable {
    /// Marketing or hardware identifier for the device, e.g. `iPhone15,3`.
    public var deviceModel: String

    /// The CPU class string, e.g. `arm64e`.
    public var cpuClass: String

    /// Total installed physical memory in bytes.
    public var totalPhysicalMemoryBytes: UInt64

    /// The operating system version, e.g. `iOS 18.2`.
    public var osVersion: String

    /// The OS build number reported by `sysctl kern.osversion`.
    public var osBuildNumber: String

    /// The application bundle short version string, e.g. `26.5.3`.
    public var bundleShortVersion: String

    /// The application bundle build number, e.g. `4216`.
    public var bundleBuildNumber: String

    /// The git SHA the host app reports when available.
    public var gitSHA: String?

    /// The build scheme or configuration label, e.g. `Debug`, `Release`.
    public var scheme: String?

    /// `true` when running on a simulator instead of physical hardware.
    public var isSimulator: Bool

    /// The BenchmarkKit framework version that produced the record.
    public var benchmarkKitVersion: String

    /// The user's active locale identifier at run start.
    public var localeIdentifier: String

    /// The user's active time zone identifier at run start.
    public var timeZoneIdentifier: String

    /// Creates a benchmark environment.
    public init(
        deviceModel: String,
        cpuClass: String,
        totalPhysicalMemoryBytes: UInt64,
        osVersion: String,
        osBuildNumber: String,
        bundleShortVersion: String,
        bundleBuildNumber: String,
        gitSHA: String? = nil,
        scheme: String? = nil,
        isSimulator: Bool,
        benchmarkKitVersion: String = BenchmarkKitVersion.current,
        localeIdentifier: String,
        timeZoneIdentifier: String
    ) {
        self.deviceModel = deviceModel
        self.cpuClass = cpuClass
        self.totalPhysicalMemoryBytes = totalPhysicalMemoryBytes
        self.osVersion = osVersion
        self.osBuildNumber = osBuildNumber
        self.bundleShortVersion = bundleShortVersion
        self.bundleBuildNumber = bundleBuildNumber
        self.gitSHA = gitSHA
        self.scheme = scheme
        self.isSimulator = isSimulator
        self.benchmarkKitVersion = benchmarkKitVersion
        self.localeIdentifier = localeIdentifier
        self.timeZoneIdentifier = timeZoneIdentifier
    }
}

/// Stable metadata keys used when lifting `BenchmarkEnvironment` fields into benchmark history.
///
/// The dashboard and export surfaces operate on run/sample metadata dictionaries. This namespace
/// provides a single additive key vocabulary so producers can flatten environment facts into
/// history without changing the persisted `BenchmarkRun` or `BenchmarkSample` schema.
public enum BenchmarkEnvironmentMetadataKey {
    /// The device hardware model identifier.
    public static let deviceModel = "environment.deviceModel"

    /// The CPU class string.
    public static let cpuClass = "environment.cpuClass"

    /// Total installed physical memory in bytes.
    public static let totalPhysicalMemoryBytes = "environment.totalPhysicalMemoryBytes"

    /// The operating system version.
    public static let osVersion = "environment.osVersion"

    /// The OS build number.
    public static let osBuildNumber = "environment.osBuildNumber"

    /// The application bundle short version.
    public static let bundleShortVersion = "environment.bundleShortVersion"

    /// The application bundle build number.
    public static let bundleBuildNumber = "environment.bundleBuildNumber"

    /// The host git SHA.
    public static let gitSHA = "environment.gitSHA"

    /// The build scheme or configuration label.
    public static let scheme = "environment.scheme"

    /// Whether the run was captured on a simulator.
    public static let isSimulator = "environment.isSimulator"

    /// The BenchmarkKit framework version that produced the record.
    public static let benchmarkKitVersion = "environment.benchmarkKitVersion"

    /// The locale identifier active at run start.
    public static let localeIdentifier = "environment.localeIdentifier"

    /// The time zone identifier active at run start.
    public static let timeZoneIdentifier = "environment.timeZoneIdentifier"
}

public extension BenchmarkEnvironment {
    /// A build reference for performance change notes introduced in this environment.
    ///
    /// The reference uses the same bundle build number that benchmark history stores in
    /// `BenchmarkEnvironmentMetadataKey.bundleBuildNumber`, so bundled notes and recorded runs
    /// can be associated without deriving causality from benchmark movement.
    func performanceChangeBuild(metadata: [String: String] = [:]) -> BenchmarkPerformanceChangeBuild {
        BenchmarkPerformanceChangeBuild(
            bundleBuildNumber: bundleBuildNumber,
            bundleShortVersion: bundleShortVersion.isEmpty ? nil : bundleShortVersion,
            sourceRevision: gitSHA?.isEmpty == false ? gitSHA : nil,
            metadata: metadata
        )
    }

    /// A stable metadata projection suitable for `BenchmarkRun.metadata` or `BenchmarkSample.metadata`.
    ///
    /// The projection is additive and string-only by design so history consumers can access
    /// environment context without decoding `BenchmarkEnvelope`.
    var historyMetadata: [String: String] {
        var metadata: [String: String] = [
            BenchmarkEnvironmentMetadataKey.deviceModel: deviceModel,
            BenchmarkEnvironmentMetadataKey.cpuClass: cpuClass,
            BenchmarkEnvironmentMetadataKey.totalPhysicalMemoryBytes: String(totalPhysicalMemoryBytes),
            BenchmarkEnvironmentMetadataKey.osVersion: osVersion,
            BenchmarkEnvironmentMetadataKey.osBuildNumber: osBuildNumber,
            BenchmarkEnvironmentMetadataKey.bundleShortVersion: bundleShortVersion,
            BenchmarkEnvironmentMetadataKey.bundleBuildNumber: bundleBuildNumber,
            BenchmarkEnvironmentMetadataKey.isSimulator: isSimulator ? "true" : "false",
            BenchmarkEnvironmentMetadataKey.benchmarkKitVersion: benchmarkKitVersion,
            BenchmarkEnvironmentMetadataKey.localeIdentifier: localeIdentifier,
            BenchmarkEnvironmentMetadataKey.timeZoneIdentifier: timeZoneIdentifier
        ]

        if let gitSHA, gitSHA.isEmpty == false {
            metadata[BenchmarkEnvironmentMetadataKey.gitSHA] = gitSHA
        }

        if let scheme, scheme.isEmpty == false {
            metadata[BenchmarkEnvironmentMetadataKey.scheme] = scheme
        }

        return metadata
    }

    /// Returns an environment populated from the running process.
    ///
    /// Hosts that want to override individual fields can build a value with the memberwise initializer
    /// and use this only as a starting point.
    static func current(
        bundleShortVersion: String,
        bundleBuildNumber: String,
        gitSHA: String? = nil,
        scheme: String? = nil
    ) -> BenchmarkEnvironment {
        BenchmarkEnvironment(
            deviceModel: SystemFacts.deviceModel,
            cpuClass: SystemFacts.cpuClass,
            totalPhysicalMemoryBytes: SystemFacts.totalPhysicalMemoryBytes,
            osVersion: SystemFacts.osVersion,
            osBuildNumber: SystemFacts.osBuildNumber,
            bundleShortVersion: bundleShortVersion,
            bundleBuildNumber: bundleBuildNumber,
            gitSHA: gitSHA,
            scheme: scheme,
            isSimulator: SystemFacts.isSimulator,
            localeIdentifier: Locale.current.identifier,
            timeZoneIdentifier: TimeZone.current.identifier
        )
    }
}

public extension BenchmarkEnvelope {
    /// Produces additive history metadata from the envelope and optional caller-supplied metadata.
    ///
    /// Caller-supplied metadata wins on key collisions so probes can override or redact individual
    /// fields without losing the rest of the environment projection.
    func historyMetadata(merging metadata: [String: String] = [:]) -> [String: String] {
        var merged = metadata
        merged.merge(environment.historyMetadata, uniquingKeysWith: { current, _ in current })
        merged.merge(extras, uniquingKeysWith: { current, _ in current })
        return merged
    }
}

/// Host-supplied addenda for a benchmark envelope.
///
/// Conform a host type (e.g. an account or feature-flag service) and pass it to a recorder so the
/// envelope carries account hashes or experiment flags without polluting the core type.
public protocol BenchmarkEnvelopeProvider: Sendable {
    /// Builds the structured environment for a run.
    func environment() async -> BenchmarkEnvironment

    /// Optional extra metadata stored alongside the envelope.
    func extras() async -> [String: String]

    /// Optional performance change notes bundled with the envelope.
    func performanceChangeNotes() async -> [BenchmarkPerformanceChangeNote]
}

public extension BenchmarkEnvelopeProvider {
    /// Default empty extras for hosts that do not need to inject metadata.
    func extras() async -> [String: String] {
        [:]
    }

    /// Default empty performance notes for hosts that do not bundle change annotations.
    func performanceChangeNotes() async -> [BenchmarkPerformanceChangeNote] {
        []
    }
}

/// The bundled envelope written to a benchmark run.
public struct BenchmarkEnvelope: Hashable, Codable, Sendable {
    /// The captured environment snapshot.
    public var environment: BenchmarkEnvironment

    /// Host-supplied extras (account hash, experiment flags, etc.).
    public var extras: [String: String]

    /// MetricKit payloads collected during the run window, encoded as JSON dictionaries.
    public var metricKit: [BenchmarkMetricKitPayload]

    /// Performance change notes imported or bundled with this run's history.
    public var performanceChangeNotes: [BenchmarkPerformanceChangeNote]

    /// Creates a benchmark envelope.
    public init(
        environment: BenchmarkEnvironment,
        extras: [String: String] = [:],
        metricKit: [BenchmarkMetricKitPayload] = [],
        performanceChangeNotes: [BenchmarkPerformanceChangeNote] = []
    ) {
        self.environment = environment
        self.extras = extras
        self.metricKit = metricKit
        self.performanceChangeNotes = performanceChangeNotes
    }

    private enum CodingKeys: String, CodingKey {
        case environment
        case extras
        case metricKit
        case performanceChangeNotes
    }

    /// Decodes an envelope while preserving compatibility with history captured before
    /// performance notes were added.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        environment = try container.decode(BenchmarkEnvironment.self, forKey: .environment)
        extras = try container.decodeIfPresent([String: String].self, forKey: .extras) ?? [:]
        metricKit = try container.decodeIfPresent([BenchmarkMetricKitPayload].self, forKey: .metricKit) ?? []
        performanceChangeNotes = try container.decodeIfPresent(
            [BenchmarkPerformanceChangeNote].self,
            forKey: .performanceChangeNotes
        ) ?? []
    }

    /// Encodes an envelope, including any bundled performance change notes.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(environment, forKey: .environment)
        try container.encode(extras, forKey: .extras)
        try container.encode(metricKit, forKey: .metricKit)
        try container.encode(performanceChangeNotes, forKey: .performanceChangeNotes)
    }
}

/// A Codable bundle of performance change notes that can be imported into benchmark history.
public struct BenchmarkPerformanceChangeNoteBundle: Hashable, Codable, Sendable {
    /// Notes in import order.
    public var notes: [BenchmarkPerformanceChangeNote]

    /// Creates a performance change note bundle.
    public init(notes: [BenchmarkPerformanceChangeNote] = []) {
        self.notes = notes
    }

    /// Decodes a performance change note bundle from JSON data.
    public init(jsonData: Data, decoder: JSONDecoder = JSONDecoder()) throws {
        self = try decoder.decode(Self.self, from: jsonData)
    }

    /// Encodes this performance change note bundle as JSON data.
    public func jsonData(encoder: JSONEncoder = JSONEncoder()) throws -> Data {
        try encoder.encode(self)
    }

    /// Returns a bundle whose notes have a build association when the import omitted one.
    ///
    /// Existing non-empty `buildIntroduced.bundleBuildNumber` values are preserved so imported
    /// notes keep the build where the change was introduced.
    public func fillingMissingBuildIntroduced(
        with buildIntroduced: BenchmarkPerformanceChangeBuild
    ) -> BenchmarkPerformanceChangeNoteBundle {
        BenchmarkPerformanceChangeNoteBundle(
            notes: notes.map { note in
                var note = note
                if note.buildIntroduced.bundleBuildNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    note.buildIntroduced = buildIntroduced
                }
                return note
            }
        )
    }
}

/// A MetricKit payload reduced to its persisted JSON representation.
///
/// The framework stores the raw payload bytes and a kind discriminator so consumers can decode
/// the structured payload without forcing the BenchmarkKit core type to import MetricKit.
public struct BenchmarkMetricKitPayload: Hashable, Codable, Sendable {
    /// The originating MetricKit payload kind.
    public enum Kind: String, Codable, Sendable {
        /// A `MXMetricPayload` daily metric payload.
        case metric
        /// A `MXDiagnosticPayload` daily diagnostic payload.
        case diagnostic
    }

    /// The kind of the underlying MetricKit payload.
    public var kind: Kind

    /// The payload's first timestamp.
    public var timeStampBegin: Date

    /// The payload's last timestamp.
    public var timeStampEnd: Date

    /// The raw JSON bytes returned by MetricKit's `jsonRepresentation()`.
    public var jsonData: Data

    /// Creates a stored MetricKit payload.
    public init(kind: Kind, timeStampBegin: Date, timeStampEnd: Date, jsonData: Data) {
        self.kind = kind
        self.timeStampBegin = timeStampBegin
        self.timeStampEnd = timeStampEnd
        self.jsonData = jsonData
    }
}

// MARK: - Sampling profiles

/// The sampling cadence and retention policy for a benchmark run.
public enum BenchmarkSamplingProfile: String, CaseIterable, Hashable, Codable, Sendable {
    /// Approximately one sample per second; summary-only persistence (no raw trace).
    case light

    /// Approximately ten samples per second; raw trace retained alongside the summary.
    case deep

    /// The nominal sampling frequency in hertz for the profile.
    public var samplesPerSecond: Double {
        switch self {
        case .light: 1
        case .deep: 10
        }
    }

    /// The interval between samples derived from `samplesPerSecond`.
    public var samplingInterval: TimeInterval {
        1.0 / samplesPerSecond
    }

    /// Whether raw samples should be persisted; `.light` keeps summary stats only.
    public var retainsRawSamples: Bool {
        switch self {
        case .light: false
        case .deep: true
        }
    }
}

// MARK: - System samples

/// The thermal state recorded with a system sample.
public enum BenchmarkThermalState: String, Hashable, Codable, Sendable {
    case nominal
    case fair
    case serious
    case critical
    case unknown

    /// Maps a `ProcessInfo.ThermalState` value into the persisted enum.
    public static func from(_ state: ProcessInfo.ThermalState) -> BenchmarkThermalState {
        switch state {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .unknown
        }
    }
}

/// A single point-in-time system observation captured while a benchmark run is active.
public struct BenchmarkSystemSample: Hashable, Codable, Sendable {
    /// The time when the sample was captured.
    public var measuredAt: Date

    /// The task's resident memory footprint in bytes.
    public var residentMemoryBytes: UInt64

    /// The task's memory footprint, as reported by `phys_footprint`.
    public var memoryFootprintBytes: UInt64

    /// The remaining headroom in bytes before the OS terminates the process for memory pressure.
    public var availableMemoryBytes: UInt64?

    /// CPU usage of the task across all threads, expressed as a 0...1 fraction of one CPU core.
    public var cpuUsageFraction: Double

    /// The current thermal state.
    public var thermalState: BenchmarkThermalState

    /// Whether low-power mode is enabled.
    public var isLowPowerModeEnabled: Bool

    /// Battery level in `0...1`, or `nil` when monitoring is unavailable.
    public var batteryLevel: Double?

    /// Free disk space in bytes for the application support volume.
    public var freeDiskBytes: UInt64?

    /// GPU utilization in `0...1` when Metal performance counters are available.
    public var gpuUsageFraction: Double?

    /// Creates a system sample.
    public init(
        measuredAt: Date,
        residentMemoryBytes: UInt64,
        memoryFootprintBytes: UInt64,
        availableMemoryBytes: UInt64? = nil,
        cpuUsageFraction: Double,
        thermalState: BenchmarkThermalState,
        isLowPowerModeEnabled: Bool,
        batteryLevel: Double? = nil,
        freeDiskBytes: UInt64? = nil,
        gpuUsageFraction: Double? = nil
    ) {
        self.measuredAt = measuredAt
        self.residentMemoryBytes = residentMemoryBytes
        self.memoryFootprintBytes = memoryFootprintBytes
        self.availableMemoryBytes = availableMemoryBytes
        self.cpuUsageFraction = cpuUsageFraction
        self.thermalState = thermalState
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.batteryLevel = batteryLevel
        self.freeDiskBytes = freeDiskBytes
        self.gpuUsageFraction = gpuUsageFraction
    }
}

// MARK: - Summary statistics

/// Summary statistics produced from a sequence of `Double` samples.
public struct BenchmarkSignalSummary: Hashable, Codable, Sendable {
    /// The minimum observed value.
    public var minimum: Double
    /// The maximum (peak) observed value.
    public var peak: Double
    /// The arithmetic mean over the sample window.
    public var average: Double
    /// The 50th percentile (median).
    public var p50: Double
    /// The 95th percentile.
    public var p95: Double
    /// The 99th percentile.
    public var p99: Double

    /// Creates a signal summary directly.
    public init(minimum: Double, peak: Double, average: Double, p50: Double, p95: Double, p99: Double) {
        self.minimum = minimum
        self.peak = peak
        self.average = average
        self.p50 = p50
        self.p95 = p95
        self.p99 = p99
    }

    /// Builds a summary from an unsorted sequence of values, returning `nil` for empty input.
    public static func make(from values: [Double]) -> BenchmarkSignalSummary? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let count = Double(sorted.count)
        let mean = sorted.reduce(0, +) / count
        return BenchmarkSignalSummary(
            minimum: sorted.first ?? 0,
            peak: sorted.last ?? 0,
            average: mean,
            p50: percentile(of: sorted, fraction: 0.50),
            p95: percentile(of: sorted, fraction: 0.95),
            p99: percentile(of: sorted, fraction: 0.99)
        )
    }

    private static func percentile(of sorted: [Double], fraction: Double) -> Double {
        if sorted.isEmpty { return 0 }
        let clamped = max(0, min(1, fraction))
        let index = Int((Double(sorted.count - 1) * clamped).rounded())
        return sorted[index]
    }
}

/// The aggregate summary written to a `BenchmarkRun` for a given system-sample window.
public struct BenchmarkSystemSummary: Hashable, Codable, Sendable {
    /// The sampling profile that produced the underlying samples.
    public var profile: BenchmarkSamplingProfile
    /// The number of samples collected.
    public var sampleCount: Int
    /// Summary of resident memory in bytes.
    public var residentMemoryBytes: BenchmarkSignalSummary?
    /// Summary of memory footprint in bytes.
    public var memoryFootprintBytes: BenchmarkSignalSummary?
    /// Summary of available memory headroom in bytes.
    public var availableMemoryBytes: BenchmarkSignalSummary?
    /// Summary of CPU usage fraction.
    public var cpuUsageFraction: BenchmarkSignalSummary?
    /// Summary of battery level fraction.
    public var batteryLevel: BenchmarkSignalSummary?
    /// Summary of free disk bytes.
    public var freeDiskBytes: BenchmarkSignalSummary?
    /// Summary of GPU usage fraction.
    public var gpuUsageFraction: BenchmarkSignalSummary?

    /// Creates a system summary directly.
    public init(
        profile: BenchmarkSamplingProfile,
        sampleCount: Int,
        residentMemoryBytes: BenchmarkSignalSummary? = nil,
        memoryFootprintBytes: BenchmarkSignalSummary? = nil,
        availableMemoryBytes: BenchmarkSignalSummary? = nil,
        cpuUsageFraction: BenchmarkSignalSummary? = nil,
        batteryLevel: BenchmarkSignalSummary? = nil,
        freeDiskBytes: BenchmarkSignalSummary? = nil,
        gpuUsageFraction: BenchmarkSignalSummary? = nil
    ) {
        self.profile = profile
        self.sampleCount = sampleCount
        self.residentMemoryBytes = residentMemoryBytes
        self.memoryFootprintBytes = memoryFootprintBytes
        self.availableMemoryBytes = availableMemoryBytes
        self.cpuUsageFraction = cpuUsageFraction
        self.batteryLevel = batteryLevel
        self.freeDiskBytes = freeDiskBytes
        self.gpuUsageFraction = gpuUsageFraction
    }

    /// Builds a summary from a recorded sample stream.
    public static func make(
        profile: BenchmarkSamplingProfile,
        samples: [BenchmarkSystemSample]
    ) -> BenchmarkSystemSummary {
        BenchmarkSystemSummary(
            profile: profile,
            sampleCount: samples.count,
            residentMemoryBytes: BenchmarkSignalSummary.make(from: samples.map { Double($0.residentMemoryBytes) }),
            memoryFootprintBytes: BenchmarkSignalSummary.make(from: samples.map { Double($0.memoryFootprintBytes) }),
            availableMemoryBytes: BenchmarkSignalSummary
                .make(from: samples.compactMap { $0.availableMemoryBytes.map(Double.init) }),
            cpuUsageFraction: BenchmarkSignalSummary.make(from: samples.map(\.cpuUsageFraction)),
            batteryLevel: BenchmarkSignalSummary.make(from: samples.compactMap(\.batteryLevel)),
            freeDiskBytes: BenchmarkSignalSummary.make(from: samples.compactMap { $0.freeDiskBytes.map(Double.init) }),
            gpuUsageFraction: BenchmarkSignalSummary.make(from: samples.compactMap(\.gpuUsageFraction))
        )
    }
}

// MARK: - System facts (platform glue)

/// Lightweight, side-effect-free accessors that read static facts about the host process.
public enum SystemFacts {
    /// Returns the hardware model identifier (e.g. `iPhone15,3`) from `sysctlbyname`.
    public static var deviceModel: String {
        sysctlString(name: "hw.machine") ?? "unknown"
    }

    /// Returns the CPU class string from `sysctlbyname` (e.g. `arm64e`).
    public static var cpuClass: String {
        sysctlString(name: "hw.cputype") ?? sysctlString(name: "machdep.cpu.brand_string") ?? "unknown"
    }

    /// Returns the total installed physical memory in bytes.
    public static var totalPhysicalMemoryBytes: UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }

    /// Returns the operating system marketing version (`major.minor.patch`).
    public static var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    /// Returns the OS build number reported by `kern.osversion`.
    public static var osBuildNumber: String {
        sysctlString(name: "kern.osversion") ?? "unknown"
    }

    /// Whether the current process is running in a simulator.
    public static var isSimulator: Bool {
        #if targetEnvironment(simulator)
            return true
        #else
            return false
        #endif
    }

    private static func sysctlString(name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        if let nullIndex = buffer.firstIndex(of: 0) {
            buffer.removeSubrange(nullIndex ..< buffer.endIndex)
        }
        return String(decoding: buffer, as: UTF8.self)
    }
}
