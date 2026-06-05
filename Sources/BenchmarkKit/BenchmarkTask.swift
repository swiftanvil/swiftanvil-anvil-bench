import Foundation
import AnvilCore

/// The result of a completed benchmark run.
public struct BenchmarkResult: Sendable {
    /// The run that was measured.
    public let run: BenchmarkRun

    /// The samples recorded during the run.
    public let samples: [BenchmarkSample]

    /// The elapsed time of the benchmark in seconds.
    public let elapsedSeconds: TimeInterval

    /// Creates a benchmark result.
    public init(run: BenchmarkRun, samples: [BenchmarkSample], elapsedSeconds: TimeInterval) {
        self.run = run
        self.samples = samples
        self.elapsedSeconds = elapsedSeconds
    }
}

/// A runner that executes benchmark work wrapped in `AnvilTask`.
public struct BenchmarkTaskRunner: Sendable {
    private let recorder: any BenchmarkRecorder
    private let measurer: any BenchmarkMeasuring

    /// Creates a benchmark task runner.
    public init(
        recorder: any BenchmarkRecorder = NoOpBenchmarkRecorder(),
        measurer: any BenchmarkMeasuring = WallClockBenchmarkMeasurer()
    ) {
        self.recorder = recorder
        self.measurer = measurer
    }

    /// Runs a benchmark scenario asynchronously using `AnvilTask<BenchmarkResult>`.
    public func run(
        descriptor: BenchmarkRunDescriptor,
        operation: @escaping @Sendable () async throws -> [BenchmarkSampleDescriptor]
    ) async throws -> AnvilTask<BenchmarkResult> {
        AnvilTask(label: "benchmark-\(descriptor.scenarioID.rawValue)") {
            let run = try await self.recorder.startRun(descriptor)
            let measurement = try await self.measurer.measure {
                let sampleDescriptors = try await operation()
                var samples: [BenchmarkSample] = []
                for sampleDescriptor in sampleDescriptors {
                    let sample = try await self.recorder.recordSample(sampleDescriptor, in: run.id)
                    samples.append(sample)
                }
                return samples
            }
            try await self.recorder.finishRun(id: run.id, endedAt: Date())
            return BenchmarkResult(
                run: run,
                samples: measurement.value,
                elapsedSeconds: measurement.elapsedSeconds
            )
        }
    }
}
