# Performance Change Notes Schema

BenchmarkKit performance change notes are stable, Codable records that can be
bundled with sample data or attached to debug/TestFlight benchmark history.
They annotate a build with expected benchmark movement without claiming that a
change caused a measured result.

## Required fields

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `BenchmarkPerformanceChangeNote.ID` | Stable note identifier. |
| `area` | `BenchmarkPerformanceChangeArea` | String-backed product or technical area. |
| `changeType` | `BenchmarkPerformanceChangeType` | Stable raw-value enum such as `optimization` or `dependency`. |
| `summary` | `String` | Concise human-readable description. |
| `expectedImpact` | `BenchmarkPerformanceExpectedImpact` | Stable raw-value enum for expected direction. |
| `affectedBenchmarks` | `[BenchmarkPerformanceChangeAffectedBenchmark]` | Suite, scenario, metric, or fingerprint references. |
| `risk` | `BenchmarkPerformanceChangeRisk` | Stable raw-value enum: `low`, `medium`, `high`, or `unknown`. |
| `buildIntroduced` | `BenchmarkPerformanceChangeBuild` | Bundle build plus optional version/revision metadata. |
| `validationNotes` | `[String]` | Profiling, experiment, or review notes that support the expectation. |

## JSON sample

```json
{
  "id": "note.export-cache-4216",
  "area": "media",
  "changeType": "optimization",
  "summary": "Reuse prepared export assets between preview and final render.",
  "expectedImpact": "improvesPerformance",
  "affectedBenchmarks": [
    {
      "suiteID": "suite.export",
      "scenarioID": "scenario.export.h264.1080p",
      "metricID": "metric.duration",
      "scenarioFingerprint": {
        "strictGates": {
          "values": [
            {
              "dimension": "workflow",
              "value": "export"
            },
            {
              "dimension": "export.kind",
              "value": "h264"
            }
          ]
        },
        "fuzzyBucket": {
          "values": [
            {
              "dimension": "duration.bucket",
              "value": "short"
            }
          ]
        }
      },
      "metadata": {
        "owner": "benchmarking"
      }
    }
  ],
  "risk": "medium",
  "buildIntroduced": {
    "bundleBuildNumber": "4216",
    "bundleShortVersion": "4.8.0",
    "sourceRevision": "abc1234",
    "metadata": {
      "train": "testflight"
    }
  },
  "validationNotes": [
    "Expected to reduce export duration for repeated preview-to-export flows.",
    "Compare only against matching scenario fingerprints and device cohorts."
  ],
  "metadata": {
    "ticket": "PERF-128"
  }
}
```
