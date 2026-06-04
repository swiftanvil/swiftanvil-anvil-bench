# BenchmarkKit

Structured benchmarking models, recording, and SwiftUI dashboards.

## Description

`BenchmarkKit` provides the core types and protocols for defining benchmark suites, scenarios, metrics, and runs. It includes cohort filtering, comparable-run grouping, performance-change notes, and a SwiftUI dashboard target (`BenchmarkKitSwiftUI`) for visualising results.

## Installation

Add the package dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/swiftanvil/swiftanvil-anvil-bench.git", from: "1.0.0"),
]
```

Then add the products to your targets:

```swift
.target(name: "MyTarget", dependencies: [
    .product(name: "BenchmarkKit", package: "swiftanvil-anvil-bench"),
]),
.target(name: "MyAppTarget", dependencies: [
    .product(name: "BenchmarkKitSwiftUI", package: "swiftanvil-anvil-bench"),
])
```

## Usage

```swift
import BenchmarkKit

// Define a suite and scenario
let suite = BenchmarkSuite(id: "export", name: "Media Export")
let scenario = BenchmarkScenario(
    id: "export.hevc.1080p",
    suiteID: suite.id,
    name: "HEVC 1080p Export",
    fingerprint: BenchmarkScenarioFingerprint(
        strictGates: [.workflow: "export", .mediaKind: "video"]
    )
)

// Record a run
let recorder: BenchmarkRecorder = MyRecorder()
let run = try await recorder.startRun(
    BenchmarkRunDescriptor(suiteID: suite.id, scenarioID: scenario.id)
)
```

## Build & Test

```bash
swift build
swift test
```
