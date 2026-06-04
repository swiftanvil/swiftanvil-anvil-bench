# ``BenchmarkKit``

Structured benchmarking models, recording, and analysis.

## Overview

`BenchmarkKit` provides the core types and protocols for defining benchmark suites, scenarios, metrics, and runs. It includes cohort filtering, comparable-run grouping, and performance-change notes.

## Topics

### Identity

- ``BenchmarkID``
- ``BenchmarkTag``

### Suites & Scenarios

- ``BenchmarkSuite``
- ``BenchmarkScenario``
- ``BenchmarkScenarioFingerprint``
- ``BenchmarkScenarioStrictGates``
- ``BenchmarkScenarioFuzzyBucket``

### Metrics & Samples

- ``BenchmarkMetric``
- ``BenchmarkMetricUnit``
- ``BenchmarkMetricDirection``
- ``BenchmarkSample``
- ``BenchmarkSampleDescriptor``

### Recording

- ``BenchmarkRun``
- ``BenchmarkRunDescriptor``
- ``BenchmarkRecorder``
- ``BenchmarkMeasuring``
- ``NoOpBenchmarkRecorder``
- ``WallClockBenchmarkMeasurer``

### Cohorts & Comparison

- ``BenchmarkCohort``
- ``BenchmarkCohortFilter``
- ``BenchmarkComparableRunGroup``
- ``BenchmarkComparison``

### Change Notes

- ``BenchmarkPerformanceChangeNote``
- ``BenchmarkPerformanceChangeArea``
- ``BenchmarkPerformanceChangeType``
- ``BenchmarkPerformanceExpectedImpact``
- ``BenchmarkPerformanceChangeRisk``
