import Foundation

/// Input used to create a benchmark run.
public struct BenchmarkRunDescriptor: Hashable, Codable, Sendable {
    /// The suite measured by the run.
    public var suiteID: BenchmarkSuite.ID

    /// The scenario measured by the run.
    public var scenarioID: BenchmarkScenario.ID

    /// The time when the run started.
    public var startedAt: Date

    /// The active or archived state for the run.
    public var archiveState: BenchmarkArchiveState

    /// Tags attached to the run.
    public var tags: Set<BenchmarkTag>

    /// Additional string metadata for consumers that need lightweight context.
    public var metadata: [String: String]

    /// Optional envelope captured at run start. Recorders write this to the resulting `BenchmarkRun`.
    public var envelope: BenchmarkEnvelope?

    /// The sampling profile that will be used to collect system samples during the run.
    public var samplingProfile: BenchmarkSamplingProfile

    /// Creates a benchmark run descriptor.
    public init(
        suiteID: BenchmarkSuite.ID,
        scenarioID: BenchmarkScenario.ID,
        startedAt: Date = Date(),
        archiveState: BenchmarkArchiveState = .active,
        tags: Set<BenchmarkTag> = [],
        metadata: [String: String] = [:],
        envelope: BenchmarkEnvelope? = nil,
        samplingProfile: BenchmarkSamplingProfile = .light
    ) {
        self.suiteID = suiteID
        self.scenarioID = scenarioID
        self.startedAt = startedAt
        self.archiveState = archiveState
        self.tags = tags
        self.metadata = metadata
        self.envelope = envelope
        self.samplingProfile = samplingProfile
    }
}

/// Input used to create a benchmark sample.
public struct BenchmarkSampleDescriptor: Hashable, Codable, Sendable {
    /// The suite measured by the sample.
    public var suiteID: BenchmarkSuite.ID

    /// The scenario measured by the sample.
    public var scenarioID: BenchmarkScenario.ID

    /// The metric measured by the sample.
    public var metricID: BenchmarkMetric.ID

    /// The numeric measurement.
    public var value: Double

    /// The time when the measurement was captured.
    public var measuredAt: Date

    /// Tags attached to the sample.
    public var tags: Set<BenchmarkTag>

    /// Additional string metadata for consumers that need lightweight context.
    public var metadata: [String: String]

    /// Creates a benchmark sample descriptor.
    public init(
        suiteID: BenchmarkSuite.ID,
        scenarioID: BenchmarkScenario.ID,
        metricID: BenchmarkMetric.ID,
        value: Double,
        measuredAt: Date = Date(),
        tags: Set<BenchmarkTag> = [],
        metadata: [String: String] = [:]
    ) {
        self.suiteID = suiteID
        self.scenarioID = scenarioID
        self.metricID = metricID
        self.value = value
        self.measuredAt = measuredAt
        self.tags = tags
        self.metadata = metadata
    }
}

/// A recorder that persists or forwards benchmark runs and samples.
public protocol BenchmarkRecorder: Sendable {
    /// Starts a run from a descriptor and returns the created run.
    func startRun(_ descriptor: BenchmarkRunDescriptor) async throws -> BenchmarkRun

    /// Records a sample for an existing run and returns the created sample.
    func recordSample(_ descriptor: BenchmarkSampleDescriptor, in runID: BenchmarkRun.ID) async throws -> BenchmarkSample

    /// Finishes an existing run.
    func finishRun(id: BenchmarkRun.ID, endedAt: Date) async throws
}

/// A recorder that accepts calls without storing benchmark history.
public struct NoOpBenchmarkRecorder: BenchmarkRecorder {
    /// Creates a no-op benchmark recorder.
    public init() {}

    /// Starts a run from a descriptor and returns a placeholder run.
    public func startRun(_ descriptor: BenchmarkRunDescriptor) async throws -> BenchmarkRun {
        BenchmarkRun(
            id: BenchmarkRun.ID("noop-run"),
            suiteID: descriptor.suiteID,
            scenarioID: descriptor.scenarioID,
            startedAt: descriptor.startedAt,
            archiveState: descriptor.archiveState,
            tags: descriptor.tags,
            metadata: descriptor.metadata,
            envelope: descriptor.envelope
        )
    }

    /// Records a sample for an existing run and returns a placeholder sample.
    public func recordSample(_ descriptor: BenchmarkSampleDescriptor, in runID: BenchmarkRun.ID) async throws -> BenchmarkSample {
        BenchmarkSample(
            id: BenchmarkSample.ID("noop-sample"),
            runID: runID,
            suiteID: descriptor.suiteID,
            scenarioID: descriptor.scenarioID,
            metricID: descriptor.metricID,
            value: descriptor.value,
            measuredAt: descriptor.measuredAt,
            tags: descriptor.tags,
            metadata: descriptor.metadata
        )
    }

    /// Finishes an existing run without storing a result.
    public func finishRun(id: BenchmarkRun.ID, endedAt: Date) async throws {}
}

/// The result of measuring an asynchronous operation.
public struct BenchmarkMeasurement<Value: Sendable>: Sendable {
    /// The value returned by the measured operation.
    public var value: Value

    /// The elapsed operation time in seconds.
    public var elapsedSeconds: TimeInterval

    /// Creates a benchmark measurement.
    public init(value: Value, elapsedSeconds: TimeInterval) {
        self.value = value
        self.elapsedSeconds = elapsedSeconds
    }
}

/// A type that can measure asynchronous work.
public protocol BenchmarkMeasuring: Sendable {
    /// Measures an asynchronous operation and returns its value with elapsed time.
    func measure<Value: Sendable>(_ operation: @Sendable () async throws -> Value) async throws -> BenchmarkMeasurement<Value>
}

/// A measurer that executes operations and reports zero elapsed time.
public struct NoOpBenchmarkMeasurer: BenchmarkMeasuring {
    /// Creates a no-op benchmark measurer.
    public init() {}

    /// Measures an asynchronous operation and returns zero elapsed time.
    public func measure<Value: Sendable>(_ operation: @Sendable () async throws -> Value) async throws -> BenchmarkMeasurement<Value> {
        let value = try await operation()
        return BenchmarkMeasurement(value: value, elapsedSeconds: 0)
    }
}

/// A measurer that uses wall-clock time.
public struct WallClockBenchmarkMeasurer: BenchmarkMeasuring {
    /// Creates a wall-clock benchmark measurer.
    public init() {}

    /// Measures an asynchronous operation using `Date` wall-clock timestamps.
    public func measure<Value: Sendable>(_ operation: @Sendable () async throws -> Value) async throws -> BenchmarkMeasurement<Value> {
        let start = Date()
        let value = try await operation()
        let end = Date()

        return BenchmarkMeasurement(
            value: value,
            elapsedSeconds: end.timeIntervalSince(start)
        )
    }
}
