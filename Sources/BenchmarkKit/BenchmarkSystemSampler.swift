import Foundation
#if canImport(Darwin)
import Darwin
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(MetricKit)
import MetricKit
#endif

/// A type that reads a single `BenchmarkSystemSample` from the running process.
///
/// The protocol exists so tests can inject deterministic readers without touching kernel APIs.
public protocol BenchmarkSystemSampleReader: Sendable {
    /// Captures one sample. The reader is responsible for choosing the timestamp.
    func readSample() -> BenchmarkSystemSample
}

/// The default reader. Uses Mach task info, `os_proc_available_memory`, and `ProcessInfo`.
public struct DefaultBenchmarkSystemSampleReader: BenchmarkSystemSampleReader {
    /// Creates the default reader.
    public init() {}

    public func readSample() -> BenchmarkSystemSample {
        let memory = MachTaskInfo.readMemory()
        let cpu = MachTaskInfo.readCPUFraction()
        let info = ProcessInfo.processInfo
        return BenchmarkSystemSample(
            measuredAt: Date(),
            residentMemoryBytes: memory.resident,
            memoryFootprintBytes: memory.footprint,
            availableMemoryBytes: SystemFacts.availableMemory,
            cpuUsageFraction: cpu,
            thermalState: BenchmarkThermalState.from(info.thermalState),
            isLowPowerModeEnabled: info.isLowPowerModeEnabled,
            batteryLevel: SystemFacts.batteryLevel,
            freeDiskBytes: SystemFacts.freeDiskBytes,
            gpuUsageFraction: nil
        )
    }
}

extension SystemFacts {
    /// Returns headroom in bytes via `os_proc_available_memory` when the symbol is reachable.
    public static var availableMemory: UInt64? {
        #if canImport(UIKit)
        if #available(iOS 13.0, *) {
            let value = os_proc_available_memory()
            return value > 0 ? UInt64(value) : nil
        }
        #endif
        return nil
    }

    /// Battery level in `0...1` when readable from the current isolation context.
    ///
    /// UIKit's `UIDevice` is main-actor-isolated; reading it from a background sampler would
    /// race. We expose the read here and let callers route through `mainActorBatteryLevel()`
    /// when they have a main-actor context. Non-iOS platforms always return `nil`.
    public static var batteryLevel: Double? {
        #if canImport(UIKit) && !os(tvOS)
        if Thread.isMainThread {
            return MainActor.assumeIsolated { mainActorBatteryLevel() }
        }
        return nil
        #else
        return nil
        #endif
    }

    #if canImport(UIKit) && !os(tvOS)
    /// Main-actor-only battery accessor that enables monitoring on first read.
    @MainActor
    public static func mainActorBatteryLevel() -> Double? {
        let device = UIDevice.current
        if !device.isBatteryMonitoringEnabled {
            device.isBatteryMonitoringEnabled = true
        }
        let level = device.batteryLevel
        return level < 0 ? nil : Double(level)
    }
    #endif

    /// Free disk bytes for the user's home volume.
    public static var freeDiskBytes: UInt64? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage.map { UInt64($0) }
    }
}

/// A periodic sampler that drives a reader at the cadence of a `BenchmarkSamplingProfile`.
///
/// The sampler is owned for the duration of a run. Call `start` once, capture an arbitrary
/// number of samples via `drain` (in `.deep`) or `summary` (always), then `stop` to release
/// the timer task.
public actor BenchmarkSystemSampler {
    private let profile: BenchmarkSamplingProfile
    private let reader: any BenchmarkSystemSampleReader
    private var samples: [BenchmarkSystemSample] = []
    private var samplingTask: Task<Void, Never>?

    /// Creates a sampler for a profile and reader.
    public init(
        profile: BenchmarkSamplingProfile,
        reader: any BenchmarkSystemSampleReader = DefaultBenchmarkSystemSampleReader()
    ) {
        self.profile = profile
        self.reader = reader
    }

    /// The sampling profile that drives the cadence and retention behavior.
    public var samplingProfile: BenchmarkSamplingProfile { profile }

    /// The number of samples currently retained.
    public var sampleCount: Int { samples.count }

    /// Starts the periodic sampling task. Safe to call multiple times; subsequent calls no-op.
    public func start() {
        guard samplingTask == nil else { return }
        let interval = profile.samplingInterval
        let reader = self.reader
        samplingTask = Task { [weak self] in
            while !Task.isCancelled {
                let sample = reader.readSample()
                await self?.append(sample)
                let nanos = UInt64(interval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
            }
        }
    }

    /// Stops the sampling task. Idempotent.
    public func stop() {
        samplingTask?.cancel()
        samplingTask = nil
    }

    /// Records a sample directly. Exposed for deterministic tests.
    public func record(_ sample: BenchmarkSystemSample) {
        append(sample)
    }

    /// Returns the raw retained samples. In `.light` profile the returned array is always empty
    /// because samples are summarized and discarded as they arrive.
    public var retainedSamples: [BenchmarkSystemSample] {
        profile.retainsRawSamples ? samples : []
    }

    /// Returns a summary computed over the samples observed so far.
    public func summary() -> BenchmarkSystemSummary {
        BenchmarkSystemSummary.make(profile: profile, samples: workingSamples())
    }

    /// Returns `(summary, rawSamples)` and clears retained state.
    public func drain() -> (summary: BenchmarkSystemSummary, samples: [BenchmarkSystemSample]) {
        let working = workingSamples()
        let summary = BenchmarkSystemSummary.make(profile: profile, samples: working)
        let raw = profile.retainsRawSamples ? samples : []
        samples.removeAll(keepingCapacity: false)
        summaryAccumulator = SummaryAccumulator()
        summaryAccumulator.consume(working)
        return (summary, raw)
    }

    // MARK: - Internals

    private var summaryAccumulator = SummaryAccumulator()

    private func append(_ sample: BenchmarkSystemSample) {
        if profile.retainsRawSamples {
            samples.append(sample)
        } else {
            // Light mode: keep only the running aggregate, never the raw row.
            summaryAccumulator.consume([sample])
        }
    }

    private func workingSamples() -> [BenchmarkSystemSample] {
        if profile.retainsRawSamples {
            return samples
        }
        return summaryAccumulator.synthesizedSamples()
    }
}

/// Running aggregate used by the `.light` profile so we can build a summary without retaining
/// raw rows. The accumulator stores per-signal value arrays internally; this is the bounded
/// trade-off light mode pays.
private struct SummaryAccumulator {
    private var resident: [Double] = []
    private var footprint: [Double] = []
    private var available: [Double] = []
    private var cpu: [Double] = []
    private var battery: [Double] = []
    private var disk: [Double] = []
    private var gpu: [Double] = []
    private var lastThermalState: BenchmarkThermalState = .unknown
    private var lastLowPower: Bool = false
    private var lastTimestamp: Date = .distantPast

    mutating func consume(_ samples: [BenchmarkSystemSample]) {
        for sample in samples {
            resident.append(Double(sample.residentMemoryBytes))
            footprint.append(Double(sample.memoryFootprintBytes))
            if let value = sample.availableMemoryBytes { available.append(Double(value)) }
            cpu.append(sample.cpuUsageFraction)
            if let value = sample.batteryLevel { battery.append(value) }
            if let value = sample.freeDiskBytes { disk.append(Double(value)) }
            if let value = sample.gpuUsageFraction { gpu.append(value) }
            lastThermalState = sample.thermalState
            lastLowPower = sample.isLowPowerModeEnabled
            lastTimestamp = sample.measuredAt
        }
    }

    func synthesizedSamples() -> [BenchmarkSystemSample] {
        // Reconstruct just enough sample rows so the summary helper can compute percentiles.
        // Each reconstructed sample carries one value from each retained signal series.
        let count = max(resident.count, footprint.count, cpu.count)
        guard count > 0 else { return [] }
        var rows: [BenchmarkSystemSample] = []
        rows.reserveCapacity(count)
        for index in 0..<count {
            rows.append(
                BenchmarkSystemSample(
                    measuredAt: lastTimestamp,
                    residentMemoryBytes: index < resident.count ? UInt64(resident[index]) : 0,
                    memoryFootprintBytes: index < footprint.count ? UInt64(footprint[index]) : 0,
                    availableMemoryBytes: index < available.count ? UInt64(available[index]) : nil,
                    cpuUsageFraction: index < cpu.count ? cpu[index] : 0,
                    thermalState: lastThermalState,
                    isLowPowerModeEnabled: lastLowPower,
                    batteryLevel: index < battery.count ? battery[index] : nil,
                    freeDiskBytes: index < disk.count ? UInt64(disk[index]) : nil,
                    gpuUsageFraction: index < gpu.count ? gpu[index] : nil
                )
            )
        }
        return rows
    }
}

// MARK: - Mach task info

/// Thin wrapper around `task_info` used by the default reader.
enum MachTaskInfo {
    struct MemoryReading {
        var resident: UInt64
        var footprint: UInt64
    }

    static func readMemory() -> MemoryReading {
        #if canImport(Darwin)
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return MemoryReading(resident: 0, footprint: 0) }
        return MemoryReading(
            resident: UInt64(info.resident_size),
            footprint: UInt64(info.phys_footprint)
        )
        #else
        return MemoryReading(resident: 0, footprint: 0)
        #endif
    }

    static func readCPUFraction() -> Double {
        #if canImport(Darwin)
        var threadList: thread_act_array_t?
        var threadCount = mach_msg_type_number_t(0)
        guard task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS, let threads = threadList else {
            return 0
        }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: threads)),
                vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.size)
            )
        }
        var totalUsage: Double = 0
        for index in 0..<Int(threadCount) {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            let result = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(THREAD_INFO_MAX)) {
                    thread_info(threads[index], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }
            guard result == KERN_SUCCESS, threadInfo.flags & TH_FLAGS_IDLE == 0 else { continue }
            totalUsage += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE)
        }
        return totalUsage
        #else
        return 0
        #endif
    }
}

// MARK: - MetricKit bridge

/// A type that receives daily MetricKit payloads and converts them into stored values.
///
/// On non-iOS platforms `start` is a no-op and `recentPayloads` is empty so the same call sites
/// compile everywhere BenchmarkKit ships.
public actor BenchmarkMetricKitBridge {
    private var payloads: [BenchmarkMetricKitPayload] = []
    #if canImport(MetricKit) && os(iOS)
    private var subscriber: MetricKitSubscriber?
    #endif

    /// Creates an idle bridge. Call `start` to subscribe to `MXMetricManager`.
    public init() {}

    /// Subscribes to MetricKit deliveries. Idempotent and safe to call on every run.
    public func start() {
        #if canImport(MetricKit) && os(iOS)
        guard subscriber == nil else { return }
        let subscriber = MetricKitSubscriber { [weak self] payload in
            Task { await self?.append(payload) }
        }
        self.subscriber = subscriber
        MXMetricManager.shared.add(subscriber)
        #endif
    }

    /// Removes the MetricKit subscription, if any.
    public func stop() {
        #if canImport(MetricKit) && os(iOS)
        if let subscriber {
            MXMetricManager.shared.remove(subscriber)
            self.subscriber = nil
        }
        #endif
    }

    /// All payloads collected since the bridge was created.
    public var recentPayloads: [BenchmarkMetricKitPayload] { payloads }

    /// Inserts a payload directly. Tests use this; the live subscriber path also routes here.
    public func append(_ payload: BenchmarkMetricKitPayload) {
        payloads.append(payload)
    }

    /// Drains buffered payloads and returns them.
    public func drain() -> [BenchmarkMetricKitPayload] {
        let copy = payloads
        payloads.removeAll(keepingCapacity: false)
        return copy
    }
}

#if canImport(MetricKit) && os(iOS)
private final class MetricKitSubscriber: NSObject, MXMetricManagerSubscriber {
    typealias Handler = @Sendable (BenchmarkMetricKitPayload) -> Void
    private let handler: Handler

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            handler(
                BenchmarkMetricKitPayload(
                    kind: .metric,
                    timeStampBegin: payload.timeStampBegin,
                    timeStampEnd: payload.timeStampEnd,
                    jsonData: payload.jsonRepresentation()
                )
            )
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            handler(
                BenchmarkMetricKitPayload(
                    kind: .diagnostic,
                    timeStampBegin: payload.timeStampBegin,
                    timeStampEnd: payload.timeStampEnd,
                    jsonData: payload.jsonRepresentation()
                )
            )
        }
    }
}
#endif
