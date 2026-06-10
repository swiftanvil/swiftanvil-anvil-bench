import Foundation

/// A point-in-time memory reading captured during the export-blocking interval.
public struct BenchmarkExportBlockingMemorySample: Hashable, Codable, Sendable {
    /// The time when the sample was captured.
    public var measuredAt: Date

    /// The task's resident memory in bytes.
    public var residentMemoryBytes: UInt64

    /// The task's `phys_footprint` memory in bytes.
    public var memoryFootprintBytes: UInt64

    /// Remaining process headroom in bytes before the OS applies memory pressure termination.
    public var availableMemoryHeadroomBytes: UInt64?

    /// Creates a memory sample for export-blocking benchmarks.
    public init(
        measuredAt: Date,
        residentMemoryBytes: UInt64,
        memoryFootprintBytes: UInt64,
        availableMemoryHeadroomBytes: UInt64? = nil
    ) {
        self.measuredAt = measuredAt
        self.residentMemoryBytes = residentMemoryBytes
        self.memoryFootprintBytes = memoryFootprintBytes
        self.availableMemoryHeadroomBytes = availableMemoryHeadroomBytes
    }
}

/// Reads a single export-blocking memory sample from the current process.
public protocol BenchmarkExportBlockingMemorySampleReader: Sendable {
    /// Captures one memory sample.
    func readSample() -> BenchmarkExportBlockingMemorySample
}

/// Default reader for export-blocking memory signals.
public struct DefaultBenchmarkExportBlockingMemorySampleReader: BenchmarkExportBlockingMemorySampleReader {
    /// Creates the default reader.
    public init() { }

    public func readSample() -> BenchmarkExportBlockingMemorySample {
        let memory = MachTaskInfo.readMemory()
        return BenchmarkExportBlockingMemorySample(
            measuredAt: Date(),
            residentMemoryBytes: memory.resident,
            memoryFootprintBytes: memory.footprint,
            availableMemoryHeadroomBytes: SystemFacts.availableMemory
        )
    }
}

/// Aggregate summary for the export-blocking memory window.
public struct BenchmarkExportBlockingMemorySummary: Hashable, Codable, Sendable {
    /// Number of memory samples aggregated into the summary.
    public var sampleCount: Int

    /// Peak resident memory observed across the blocking interval.
    public var peakResidentMemoryBytes: UInt64

    /// Peak `phys_footprint` observed across the blocking interval.
    public var peakMemoryFootprintBytes: UInt64

    /// Lowest available headroom observed across the blocking interval.
    public var minimumAvailableMemoryHeadroomBytes: UInt64?

    /// Mean resident memory across the blocking interval.
    public var averageResidentMemoryBytes: Double

    /// Mean `phys_footprint` across the blocking interval.
    public var averageMemoryFootprintBytes: Double

    /// Mean available headroom across the blocking interval.
    public var averageAvailableMemoryHeadroomBytes: Double?

    /// Creates a memory summary for the export-blocking interval.
    public init(
        sampleCount: Int,
        peakResidentMemoryBytes: UInt64,
        peakMemoryFootprintBytes: UInt64,
        minimumAvailableMemoryHeadroomBytes: UInt64?,
        averageResidentMemoryBytes: Double,
        averageMemoryFootprintBytes: Double,
        averageAvailableMemoryHeadroomBytes: Double?
    ) {
        self.sampleCount = sampleCount
        self.peakResidentMemoryBytes = peakResidentMemoryBytes
        self.peakMemoryFootprintBytes = peakMemoryFootprintBytes
        self.minimumAvailableMemoryHeadroomBytes = minimumAvailableMemoryHeadroomBytes
        self.averageResidentMemoryBytes = averageResidentMemoryBytes
        self.averageMemoryFootprintBytes = averageMemoryFootprintBytes
        self.averageAvailableMemoryHeadroomBytes = averageAvailableMemoryHeadroomBytes
    }

    /// Materializes the export-blocking benchmark samples derived from this summary.
    public func benchmarkSamples(
        scenarioID: BenchmarkScenario.ID,
        suiteID: BenchmarkSuite.ID = BenchmarkExportBlocking.suiteID,
        measuredAt: Date = Date(),
        tags: Set<BenchmarkTag> = [],
        metadata: [String: String] = [:]
    ) -> [BenchmarkSampleDescriptor] {
        var samples = [
            BenchmarkSampleDescriptor(
                suiteID: suiteID,
                scenarioID: scenarioID,
                metricID: BenchmarkExportBlocking.peakResidentMemoryMetricID,
                value: Double(peakResidentMemoryBytes),
                measuredAt: measuredAt,
                tags: tags,
                metadata: metadata
            ),
            BenchmarkSampleDescriptor(
                suiteID: suiteID,
                scenarioID: scenarioID,
                metricID: BenchmarkExportBlocking.peakMemoryFootprintMetricID,
                value: Double(peakMemoryFootprintBytes),
                measuredAt: measuredAt,
                tags: tags,
                metadata: metadata
            )
        ]

        if let minimumAvailableMemoryHeadroomBytes {
            samples.append(
                BenchmarkSampleDescriptor(
                    suiteID: suiteID,
                    scenarioID: scenarioID,
                    metricID: BenchmarkExportBlocking.minAvailableMemoryHeadroomMetricID,
                    value: Double(minimumAvailableMemoryHeadroomBytes),
                    measuredAt: measuredAt,
                    tags: tags,
                    metadata: metadata
                )
            )
        }

        return samples
    }
}

/// A low-overhead sampler for export-blocking memory signals.
///
/// Unlike the general-purpose `BenchmarkSystemSampler`, this sampler only reads resident memory,
/// memory footprint, and available headroom. In `.light` mode it keeps an O(1) running summary
/// and does not retain raw rows, which avoids per-sample array growth during the blocking window.
public actor BenchmarkExportBlockingSampler {
    private let profile: BenchmarkSamplingProfile
    private let reader: any BenchmarkExportBlockingMemorySampleReader
    private var samples: [BenchmarkExportBlockingMemorySample] = []
    private var samplingTask: Task<Void, Never>?
    private var summaryAccumulator = SummaryAccumulator()

    /// Creates a sampler for the export-blocking interval.
    public init(
        profile: BenchmarkSamplingProfile,
        reader: any BenchmarkExportBlockingMemorySampleReader = DefaultBenchmarkExportBlockingMemorySampleReader()
    ) {
        self.profile = profile
        self.reader = reader
    }

    /// The sampling profile that drives the cadence and retention behavior.
    public var samplingProfile: BenchmarkSamplingProfile {
        profile
    }

    /// The number of samples currently captured into the running summary.
    public var sampleCount: Int {
        summaryAccumulator.sampleCount
    }

    /// The retained raw samples. `.light` mode always returns an empty array.
    public var retainedSamples: [BenchmarkExportBlockingMemorySample] {
        profile.retainsRawSamples ? samples : []
    }

    /// Starts the periodic sampling task. Safe to call multiple times.
    public func start() {
        guard samplingTask == nil else { return }
        let interval = profile.samplingInterval
        let reader = reader
        samplingTask = Task { [weak self] in
            while !Task.isCancelled {
                let sample = reader.readSample()
                await self?.append(sample)
                let nanos = UInt64(interval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
            }
        }
    }

    /// Stops the periodic sampling task.
    public func stop() {
        samplingTask?.cancel()
        samplingTask = nil
    }

    /// Records a sample directly. Exposed for deterministic callers and tests.
    public func record(_ sample: BenchmarkExportBlockingMemorySample) {
        append(sample)
    }

    /// Returns the current memory summary, or `nil` when no samples have been observed.
    public func summary() -> BenchmarkExportBlockingMemorySummary? {
        summaryAccumulator.snapshot()
    }

    /// Returns `(summary, rawSamples)` and clears retained state.
    public func drain()
        -> (summary: BenchmarkExportBlockingMemorySummary?, samples: [BenchmarkExportBlockingMemorySample])
    {
        let summary = summaryAccumulator.snapshot()
        let rawSamples = profile.retainsRawSamples ? samples : []
        samples.removeAll(keepingCapacity: false)
        summaryAccumulator = SummaryAccumulator()
        return (summary, rawSamples)
    }

    private func append(_ sample: BenchmarkExportBlockingMemorySample) {
        summaryAccumulator.consume(sample)
        if profile.retainsRawSamples {
            samples.append(sample)
        }
    }
}

/// Measured sampling overhead for the export-blocking sampler.
public struct BenchmarkExportBlockingSamplerOverhead: Hashable, Sendable {
    /// The profile whose cadence was used to judge distortion risk.
    public var profile: BenchmarkSamplingProfile

    /// Number of iterations included in the benchmark loop.
    public var iterationCount: Int

    /// Total baseline loop time in nanoseconds.
    public var baselineLoopNanoseconds: Double

    /// Total sample-recording loop time in nanoseconds.
    public var sampledLoopNanoseconds: Double

    /// Mean incremental overhead per sample after subtracting the baseline loop.
    public var incrementalNanosecondsPerSample: Double

    /// Ratio of per-sample overhead to the profile's nominal interval.
    public var intervalDutyCycle: Double

    /// Creates a sampler-overhead measurement.
    public init(
        profile: BenchmarkSamplingProfile,
        iterationCount: Int,
        baselineLoopNanoseconds: Double,
        sampledLoopNanoseconds: Double,
        incrementalNanosecondsPerSample: Double,
        intervalDutyCycle: Double
    ) {
        self.profile = profile
        self.iterationCount = iterationCount
        self.baselineLoopNanoseconds = baselineLoopNanoseconds
        self.sampledLoopNanoseconds = sampledLoopNanoseconds
        self.incrementalNanosecondsPerSample = incrementalNanosecondsPerSample
        self.intervalDutyCycle = intervalDutyCycle
    }
}

/// Helpers for validating that export-blocking memory sampling stays cheap enough not to skew
/// blocking-duration measurements.
public enum BenchmarkExportBlockingSamplerBenchmark {
    /// Measures the incremental cost of `reader.readSample()` plus `sampler.record(_:)` against
    /// an empty loop baseline. Use the reported `intervalDutyCycle` to confirm the sampler stays
    /// well below the selected cadence budget.
    public static func measureSamplingOverhead(
        iterations: Int = 1000,
        profile: BenchmarkSamplingProfile = .deep,
        reader: any BenchmarkExportBlockingMemorySampleReader = DefaultBenchmarkExportBlockingMemorySampleReader()
    ) async -> BenchmarkExportBlockingSamplerOverhead {
        precondition(iterations > 0, "iterations must be greater than zero")

        let clock = ContinuousClock()
        let sampler = BenchmarkExportBlockingSampler(profile: profile, reader: reader)

        let baselineStart = clock.now
        for _ in 0 ..< iterations { }
        let baselineNanoseconds = nanoseconds(from: baselineStart.duration(to: clock.now))

        let sampledStart = clock.now
        for _ in 0 ..< iterations {
            await sampler.record(reader.readSample())
        }
        let sampledNanoseconds = nanoseconds(from: sampledStart.duration(to: clock.now))

        let incrementalPerSample = max(0, sampledNanoseconds - baselineNanoseconds) / Double(iterations)
        let intervalDutyCycle = incrementalPerSample / (profile.samplingInterval * 1_000_000_000)

        return BenchmarkExportBlockingSamplerOverhead(
            profile: profile,
            iterationCount: iterations,
            baselineLoopNanoseconds: baselineNanoseconds,
            sampledLoopNanoseconds: sampledNanoseconds,
            incrementalNanosecondsPerSample: incrementalPerSample,
            intervalDutyCycle: intervalDutyCycle
        )
    }

    private static func nanoseconds(from duration: Duration) -> Double {
        let components = duration.components
        return (Double(components.seconds) * 1_000_000_000) + (Double(components.attoseconds) / 1_000_000_000)
    }
}

private struct SummaryAccumulator {
    var sampleCount = 0
    var peakResidentMemoryBytes: UInt64 = 0
    var peakMemoryFootprintBytes: UInt64 = 0
    var minimumAvailableMemoryHeadroomBytes: UInt64?
    var residentTotalBytes: Double = 0
    var footprintTotalBytes: Double = 0
    var availableTotalBytes: Double = 0
    var availableSampleCount = 0

    mutating func consume(_ sample: BenchmarkExportBlockingMemorySample) {
        sampleCount += 1
        peakResidentMemoryBytes = max(peakResidentMemoryBytes, sample.residentMemoryBytes)
        peakMemoryFootprintBytes = max(peakMemoryFootprintBytes, sample.memoryFootprintBytes)
        residentTotalBytes += Double(sample.residentMemoryBytes)
        footprintTotalBytes += Double(sample.memoryFootprintBytes)

        if let available = sample.availableMemoryHeadroomBytes {
            if let currentMinimum = minimumAvailableMemoryHeadroomBytes {
                minimumAvailableMemoryHeadroomBytes = min(currentMinimum, available)
            } else {
                minimumAvailableMemoryHeadroomBytes = available
            }
            availableTotalBytes += Double(available)
            availableSampleCount += 1
        }
    }

    func snapshot() -> BenchmarkExportBlockingMemorySummary? {
        guard sampleCount > 0 else { return nil }
        let averageAvailable: Double? = if availableSampleCount > 0 {
            availableTotalBytes / Double(availableSampleCount)
        } else {
            nil
        }

        return BenchmarkExportBlockingMemorySummary(
            sampleCount: sampleCount,
            peakResidentMemoryBytes: peakResidentMemoryBytes,
            peakMemoryFootprintBytes: peakMemoryFootprintBytes,
            minimumAvailableMemoryHeadroomBytes: minimumAvailableMemoryHeadroomBytes,
            averageResidentMemoryBytes: residentTotalBytes / Double(sampleCount),
            averageMemoryFootprintBytes: footprintTotalBytes / Double(sampleCount),
            averageAvailableMemoryHeadroomBytes: averageAvailable
        )
    }
}
