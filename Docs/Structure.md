# BenchmarkKit Source & Docs Structure Standard

This document is the source-owned structure guide for BenchmarkKit. Every new
file added to the package, the Zaps benchmarking adapter, or the supporting
docs/scripts must land in the layer described here. The boundary script at
`scripts/check-benchmark-boundaries.sh` enforces the parts of this standard
that can be checked mechanically; the rest is enforced by review against
this document.

Failure messages from the boundary script point readers back here by path
(`zaps-app/BenchmarkKit/Docs/Structure.md`) plus the specific rule id.

---

## 1. Why this standard exists

BenchmarkKit is an internal performance tool. Drift across the four
benchmarking layers (`BenchmarkKit`, `BenchmarkKitSwiftUI`, `ZapsBenchmarking`,
and the app's `Turnip/Benchmarking` composition) is what made the previous
review pass painful: feature files imported `BenchmarkKit` directly, the
SwiftUI dashboard absorbed view children that belonged in dedicated files,
and several proposals casually suggested localization plumbing that has no
business inside a developer-only tool. The standard pins down the layer
contracts up front so contributors do not have to re-derive them on every PR.

## 2. Layer map

The boundary script treats these directories as authoritative; do not
restructure them without updating both this guide and the script.

### 2.1 `BenchmarkKit` (`zaps-app/BenchmarkKit/Sources/BenchmarkKit/`)

The generic, app-agnostic core. Allowed contents:

- **Core domain models** — suites, scenarios, metrics, runs, samples,
  envelopes, identities, cohorts, tags. (`BenchmarkModels.swift`,
  `BenchmarkIdentity.swift`, `BenchmarkCohort.swift`,
  `BenchmarkEnvironment.swift`.)
- **Recording APIs** — recorder protocols, sampler protocols, and the
  no-op / wall-clock default implementations.
  (`BenchmarkRecording.swift`, `BenchmarkSystemSampler.swift`,
  `BenchmarkExportBlockingSampler.swift`,
  `BenchmarkExportBlockingMetrics.swift`.)
- **Query / comparison APIs** — query primitives, comparison computations,
  presentation helpers, title composition, value formatting.
  (`BenchmarkQueries.swift`, `BenchmarkComparison.swift`,
  `BenchmarkPresentation.swift`, `BenchmarkTitleComposer.swift`,
  `BenchmarkValueFormatter.swift`.)

Not allowed: SwiftUI imports, SwiftData, app-module imports, Zaps-specific
identifiers, on-disk loaders, demo data, or any catalog that names a
product/feature.

### 2.2 `BenchmarkKitSwiftUI` (`zaps-app/BenchmarkKit/Sources/BenchmarkKitSwiftUI/`)

The generic SwiftUI dashboard shell. Allowed contents:

- **Dashboard screens** — one file per top-level screen
  (`BenchmarkDashboard.swift`, `BenchmarkOverviewView.swift`,
  `BenchmarkComparisonListView.swift`, `BenchmarkComparisonDetailView.swift`,
  `BenchmarkGroupListView.swift`, `BenchmarkExportView.swift`,
  `BenchmarkSampleDrillView.swift`, `BenchmarkDetailContextView.swift`,
  `BenchmarkCohortComparisonView.swift`).
- **Reusable SwiftUI components** — chart panels, filter bars, status
  styles, liquid-glass surfaces, distribution components, shared views
  (`BenchmarkTrendChartView.swift`,
  `BenchmarkMetricComparisonChartView.swift`,
  `BenchmarkComparisonChartPanel.swift`,
  `BenchmarkDistributionChartView.swift`, `BenchmarkDistribution.swift`,
  `BenchmarkDashboardFilterBar.swift`, `BenchmarkDashboardFilters.swift`,
  `BenchmarkStatusStyle.swift`, `BenchmarkLiquidGlass.swift`,
  `BenchmarkSharedViews.swift`).
- **Dashboard view models / state** — `BenchmarkDashboardModels.swift`,
  `BenchmarkDashboardContentView.swift`,
  `BenchmarkDashboardStateViews.swift`.
- **Loaders & adapters** — `BenchmarkDashboardLoader.swift`. The loader is
  the only file allowed to convert raw `BenchmarkHistoryDataSource` calls
  into screen-ready collections; do not duplicate that logic in views.
- **Formatters** — `BenchmarkExportFormatter.swift`. Pure formatting only;
  no I/O.
- **Demo data** — `BenchmarkDashboardDemoData.swift`. Only used by previews
  and tests. No demo data lives inside production view files.
- **Sub-flows** — `DashboardFlow/` for navigation glue specific to the
  dashboard journey. Each sub-flow file owns a single screen, sheet, or
  cohesive group of reusable components (overview/home,
  suite-detail, scenario-detail, scenario filter sheet, overview summary
  views, metric card views, metric detail subviews, and dashboard chrome
  primitives).

File-size policy. SwiftUI files in this target must stay below
**400 lines**. The boundary script enforces this with a tight allowlist
that names only files known to exceed the threshold today
(`BenchmarkDashboardLoader.swift`, `BenchmarkDashboardDemoData.swift`).
Allowlist entries are transient: they must be removed the moment a file
drops below the ceiling so a stale entry never hides the next regression,
and the only legitimate way to add to the list is when an existing
oversized file is split into a focused module while one stubborn shell
remains over the ceiling for follow-up work. Adding a new oversized file
or growing an unrelated file past the threshold is a violation, and the
allowlist is not the place to "unblock" feature work — extract a subview
into its own file instead.

Not allowed: app-module imports, SwiftData, Zaps-specific catalog or
identifier names, any localization plumbing (see §3), and inline view
helpers that are large enough to belong in their own file.

### 2.3 `ZapsBenchmarking` (`zaps-app/ZapsBenchmarking/Sources/ZapsBenchmarking/`)

The Zaps-specific catalog adapter. Allowed contents:

- App / module / flow / screen / scenario / metric catalog definitions
  that map Zaps concepts into `BenchmarkKit` primitives.
- Zaps-specific tag identifier constants and starter vocabulary.
- Probe lifecycle types that translate Zaps events into recorder calls.

Allowed imports: `Foundation`, `BenchmarkKit`. Not allowed: `SwiftUI`,
`SwiftData`, `BenchmarkKitSwiftUI`, or any app module
(`Turnip`, `UserIdentity`, `Rooms`, `Core`, `CoreUI`, `Networking`,
`ZapModels`, `ZapUtils`, `Zaps`). This stays true even for "small
convenience" — features compose adapters through the app's benchmarking
composition, not by reaching down into `ZapsBenchmarking`.

Benchmark registry ownership lives in `ZapsBenchmarkCatalog.zapsApp` and is
exposed through `benchmarkRegistryEntries`. Registry entries must be derived
from existing suites, scenarios, metrics, and probes so identifier stability
stays append-only. Each entry records:

- Benchmark IDs: matrix, suite, scenario, metric, and probe identifiers.
- Workflow owner: the product-area owner retained in catalog metadata.
- Measured journeys: scenario names represented by the matrix.
- Key metrics: scenario primary metrics when configured, otherwise the
  matrix's metric IDs.
- Threshold logic: the `BenchmarkMetric.direction` interpretation plus
  BenchmarkKit's percentage and raw-delta movement suppression.
- Mapped code areas: semicolon-delimited source areas in matrix metadata
  that reviewers can use when routing benchmark movement.
- Dashboard context: the suite and sparse probe count used for dashboard
  presentation.

Path-to-benchmark governance lives beside the registry as
`ZapsBenchmarkCatalog.benchmarkPathMappings`. It emits Codable
`ZapsBenchmarkPathMapping` values derived from the same matrices as
`benchmarkRegistryEntries`, so boundary tooling and support code can map a
path to known matrix, suite, scenario, metric, and probe IDs without parsing
this document.

Each matrix contributes:

- One `workflow` path in the form
  `<app-id>/<module-id>/<flow-id>/<screen-id>`. The screen component is
  omitted when the matrix has no screen.
- One `codeArea` path for each semicolon-delimited repo-relative prefix in
  the matrix's `codeAreas` metadata.

For source changes, use
`ZapsBenchmarkCatalog.benchmarkPathMappings(containing:)` with a repo-relative
path such as `zaps-app/ZapsBenchmarking/Sources/ZapsBenchmarking/...`. The
matcher is path-segment aware, so a mapping for `zaps-app/BenchmarkKit` covers
files under that directory but not similarly named sibling directories.

Current registry coverage:

| Matrix ID | Workflow path | Owner | Measured journeys | Key metrics | Threshold logic | Mapped code areas |
| --- | --- | --- | --- | --- | --- | --- |
| `matrix.feed.rendering` | `app.zaps/module.turnip/flow.feed/screen.feed` | `zaps` | Launch to Feed; Scroll Feed | `metric.launch-latency`; `metric.memory`; `metric.frame-rate` | Per-metric direction, with BenchmarkKit threshold suppression. | `zaps-app/Turnip/Benchmarking`; `zaps-app/Rooms/Sources/Rooms/Zaps` |
| `matrix.feed.legacy-imports` | `app.zaps/module.turnip/flow.onboarding/screen.legacy-contacts` | `zaps` | Legacy Contact Import | `metric.payload-size` | Lower values are better, with BenchmarkKit threshold suppression. | `zaps-app/Turnip/Onboarding`; `zaps-app/Rooms/Sources/Rooms/Zaps` |
| `matrix.rooms.experience` | `app.zaps/module.rooms/flow.room/screen.room-timeline` | `rooms` | Open Room; Scroll Room Timeline | `metric.launch-latency`; `metric.memory` | Lower values are better, with BenchmarkKit threshold suppression. | `zaps-app/Rooms/Sources/Rooms/Zaps`; `zaps-app/Rooms/Sources/Rooms/Views` |
| `matrix.creation.collage-editor` | `app.zaps/module.rooms/flow.creation/screen.collage-editor` | `creation` | Open Collage Editor; Export Collage; Ingest Collage Video; Open Collage Draft | `metric.creation.collage-video-total-duration`; `metric.creation.collage-draft-load-total-duration` | Per-metric direction, with BenchmarkKit threshold suppression. | `zaps-app/Rooms/Sources/Rooms/Views/CameraAndEdit`; `zaps-app/ZapsBenchmarking/Sources/ZapsBenchmarking/Workflows/Media` |
| `matrix.developer-experience.package-build` | `app.zaps-workspace/module.packages/flow.build` | `platform` | Build Benchmark Packages | `metric.build-duration` | Lower values are better, with BenchmarkKit threshold suppression. | `zaps-app/BenchmarkKit`; `zaps-app/ZapsBenchmarking` |

### 2.4 App composition (`zaps-app/Turnip/Benchmarking/`)

The only layer allowed to wire `BenchmarkKitSwiftUI` to the rest of the
app. Allowed contents:

- `ZapsBenchmarkingComposition` — installs the developer benchmark
  history provider and the recorder/measurer dependencies.
- `ZapsBenchmarkDashboardCatalogFactory` — projects the
  `ZapsBenchmarkCatalog` into a `BenchmarkDashboardCatalog`.
- `ZapsSwiftDataBenchmarkStore` — the only place SwiftData touches
  benchmark state.

Availability checks (`#available(iOS 17, *)`, Debug-only gating) live in
this composition. Features must consume the resulting protocol (history
provider, recorder, measurer) and never import `BenchmarkKit` or
`BenchmarkKitSwiftUI` directly.

### 2.5 Docs (`zaps-app/BenchmarkKit/Docs/`)

- `zaps-app/BenchmarkKit/Docs/Structure.md` — this file. Source-owned
  and authoritative for the boundary script and CI workflow. The
  repo-level `docs/` tree is gitignored and must not host a duplicate
  copy; cross-cutting docs link here instead.
- `zaps-app/BenchmarkKit/Docs/dashboard-ia.md` — IA / interaction
  research for the dashboard.
- `zaps-app/BenchmarkKit/Docs/aggregation-design.md` — aggregation /
  comparison design.
- `zaps-app/BenchmarkKit/Docs/assets/` — written notes that back the
  IA research. No screenshots of third-party tooling.

### 2.6 Tooling

- `scripts/check-benchmark-boundaries.sh` — boundary enforcement.
- `.github/workflows/benchmark-boundaries.yml` — CI workflow that runs
  the boundary script on both the live tree and the negative fixture.
- `analysis/benchmarkkit-boundary-drift/negative-fixture/` — checked-in
  fixture proving every boundary rule fails when violated.

## 3. Localization policy

BenchmarkKit is an internal, developer-only tool. It is not localized and
must not adopt localization plumbing.

The following are not allowed anywhere under
`zaps-app/BenchmarkKit/`, `zaps-app/ZapsBenchmarking/`, or the negative
fixture's mirror of those trees:

- `Localizable.strings` files.
- `Localizable.xcstrings` or any other `.xcstrings` string-catalog file.
- `NSLocalizedString(...)` calls.
- `String(localized: ...)` initializers.
- `LocalizedStringKey`-driven view APIs (typed parameters or `verbatim:`
  workarounds used to bypass localization key extraction).

Strings in this tool are plain `String` literals. If a debug build needs
formatted output, use `String(format:)`, `String.init(_:)`, or one of the
existing formatter types in `BenchmarkKitSwiftUI`. The boundary script
flags every violation by file/line and points back to this section.

Stop conditions. If a production feature genuinely needs localized
benchmarking copy, surface the problem to the manager and add the
localized copy in the calling feature layer, not inside the BenchmarkKit
targets. Do not introduce an exception list in
`scripts/check-benchmark-boundaries.sh` for these rules.

## 4. How to add a new file

1. Identify the layer (§2). If a file is borderline between two layers,
   pick the more generic one only when the file's contents are genuinely
   reusable; otherwise pick the more specific one.
2. Place the file under the matching directory using the existing naming
   convention (`Benchmark*` for SwiftUI/Core, plain product-area names for
   `ZapsBenchmarking`).
3. Confirm the new file does not introduce a disallowed import or
   localization API. The boundary script will reject these but it is
   cheaper to know up front than to chase a CI failure.
4. If you are touching `BenchmarkKitSwiftUI`, keep the new file under the
   400-line ceiling. If you are tempted to grow one of the allowlisted
   oversized files further, extract a subview/helper into its own file
   instead.

## 5. How to evolve this guide

This document is the source of truth. To change a layer contract:

1. Update this file in the same PR as the code/script change.
2. Update `scripts/check-benchmark-boundaries.sh` to match (rule
   additions, allowlist changes, and the corresponding negative-fixture
   coverage).
3. Update `analysis/benchmarkkit-boundary-drift/negative-fixture/` so it
   continues to exercise every rule.

The boundary CI workflow runs both the positive and negative checks on
every PR that touches the relevant paths; treat its output as the final
arbiter of whether your change matches the guide.
