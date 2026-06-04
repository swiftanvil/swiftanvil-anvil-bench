# BenchmarkKit Dashboard — IA & Interaction Patterns

Research artifact for the C₂ dashboard implementation (T-R004). Defines the
information architecture (IA), the canonical navigation pattern, the chart
vocabulary, filter affordances, and the empty / loading / error patterns that
the dashboard must implement.

This document is intentionally framework-agnostic: it is a research synthesis,
not a SwiftUI spec. Implementation lives in T-R004.

---

## 1. Goals

The dashboard surfaces benchmark results captured by BenchmarkKit so that an
engineer can answer four questions, in order of frequency:

1. **Is anything regressing right now?** (Overview triage.)
2. **How is this specific metric trending?** (Metric detail.)
3. **What changed between two builds / cohorts / tags?** (Comparison.)
4. **Why did this particular sample look weird?** (Drill into a single run.)

The IA below is organised around that question hierarchy.

---

## 2. External references surveyed

Five established performance / observability surfaces were reviewed. For each,
the notes below summarise the IA pattern, the dominant chart vocabulary, and
the affordances that translate to BenchmarkKit. Screenshots are not embedded
inline (this document must render cleanly without external assets); annotated
notes act as the reference.

### 2.1 Xcode Organizer (MetricKit-backed)

- **Where to look:** Xcode → Window → Organizer → *Metrics* tab. Pick an app,
  then a metric (Launch Time, Hang Rate, Disk Writes, Memory, Battery, Scroll
  Hitches, etc.).
- **IA pattern:** Two-pane. Left rail = metric list; right pane = trend chart
  with percentile bands (`p50`, `p90`) over a rolling window of TestFlight /
  App Store versions.
- **Chart vocabulary:** Versioned bar / band charts with the device-class
  filter at the top (All Devices / Specific Device / iPad / iPhone) and a
  build-channel filter (App Store / TestFlight). The version axis is **build
  number on the x-axis**, not wall-clock time — this matters: it reads "did
  this build move the needle?", not "what happened on Tuesday?".
- **Affordances that translate:** Device-class filter chips, build axis,
  percentile bands as the default summary (not means), inline regression call-
  outs ("Worse than previous version").
- **Annotated note (`assets/xcode-organizer.md`):** See the assets directory
  for a written walkthrough of the Organizer layout; no proprietary screenshot
  is checked in.

### 2.2 Firebase Performance Monitoring

- **Where to look:** Firebase console → Performance → *Dashboard* and *Traces*
  tabs.
- **IA pattern:** Overview KPI cards on top (app start, network success rate,
  slow / frozen frames) → click-through to a per-trace detail screen that
  shows duration distribution + a breakdown by attribute (country, device,
  app version, custom attribute).
- **Chart vocabulary:** Line charts over wall-clock time with a configurable
  date range; **distribution percentile sparklines (p50 / p90 / p95)** are the
  primary readout for any duration metric. Attribute drill renders as a sorted
  table with sparklines per row.
- **Affordances that translate:** Attribute facets ("group by"), version
  comparison, "issues" pane that surfaces regressions auto-detected against a
  baseline.
- **Annotated note (`assets/firebase-performance.md`).**

### 2.3 Sentry Performance

- **Where to look:** Sentry → Performance → *Transactions* / *Trends*.
- **IA pattern:** Three-deep. *Performance overview* (per-transaction p50 /
  p95 / failure rate table) → *Transaction summary* (trend, distribution
  histogram, related events) → *Event detail* (single trace waterfall).
- **Chart vocabulary:**
  - **Trend chart** with shaded p95 envelope.
  - **Duration histogram** (distribution) on the transaction summary so the
    user can see whether the metric is bimodal vs heavy-tailed — the mean
    alone hides this.
  - **Regression list:** "Trends" surface that explicitly ranks transactions
    by *change in p95* against a baseline window.
- **Affordances that translate:** Tag-based filtering (Sentry's `tags:` query
  language), saved searches, environment / release facets, and the
  "Compare to previous period" toggle.
- **Annotated note (`assets/sentry-performance.md`).**

### 2.4 Embrace

- **Where to look:** Embrace dashboard → *Performance* and *User Timelines*.
- **IA pattern:** Embrace leans heavily on the **session-as-unit** model. The
  IA is: cohort overview → metric detail → individual user session timeline
  with annotated events.
- **Chart vocabulary:** Stacked area charts for session counts segmented by
  outcome (clean / hang / crash), and box-and-whisker style distributions for
  startup and screen-load durations.
- **Affordances that translate:** Cohort selectors (user tier, app version,
  device), and the *user timeline drill* — the single most useful idea to
  borrow when the dashboard's "Drill" screen needs to show what happened
  around a specific captured sample.
- **Annotated note (`assets/embrace.md`).**

### 2.5 Datadog RUM

- **Where to look:** Datadog → UX Monitoring → RUM Applications → Performance.
- **IA pattern:** Overview dashboard composed of **widgets** (top-N tables,
  time series, distribution heatmaps) on a single scrollable page, with
  side-panel drill on click. Every widget has the same control header:
  metric, aggregation (avg / p75 / p95 / p99), grouping, filter.
- **Chart vocabulary:**
  - **Heatmap** for distribution-over-time — invaluable for showing a fat
    tail forming without committing to a single percentile.
  - **Top-N table with delta column** for "what regressed since last
    release".
  - **Compare overlay**: same time-series rendered for `release:N` vs
    `release:N-1`.
- **Affordances that translate:** Persistent filter bar at the top of every
  screen ("envelope facets" in BenchmarkKit terms — see §5), and the side-
  panel pattern for drill so the user does not lose context.
- **Annotated note (`assets/datadog-rum.md`).**

### 2.6 Linear — Project / Cycle performance views (supplementary)

- **Where to look:** Linear → any project → *Insights* / cycle progress.
- **IA pattern:** This is not a performance tool, but Linear's cycle-progress
  view is the cleanest example of a **comparison-against-baseline** chart in
  modern product UI: a thin trend line with a faint "expected" line behind it.
- **Affordances that translate:** Visual minimalism in the comparison screen,
  hover-tooltip-as-table for raw numbers, and the convention that the
  baseline ("scope") is always rendered, never hidden behind a toggle.
- **Annotated note (`assets/linear-insights.md`).**

> Five-reference floor is satisfied by §2.1–§2.5; §2.6 is a supplementary
> reference for the comparison screen idiom only.

---

## 3. Canonical navigation pattern

**Recommendation: Overview → Metric → Comparison → Drill.**

A single, linear, breadcrumbed flow. Each screen has exactly one job and a
clear handoff to the next.

```
Overview
   │
   │  tap a metric card
   ▼
Metric (trend + distribution for one metric)
   │
   ├──► Comparison (this metric, two cohorts/builds/tags side-by-side)
   │
   └──► Drill (one captured sample: raw envelope, tags, related samples)
```

### 3.1 Tradeoffs considered

| Pattern | Pro | Con | Verdict |
|---|---|---|---|
| **Overview → Metric → Comparison → Drill** (chosen) | Matches the four user questions 1:1. Each screen has one job. Breadcrumb is obvious. | Comparison and Drill are siblings, not nested; users may expect Drill *inside* Comparison. Mitigated by allowing Drill entry from either Metric or Comparison. | ✅ |
| Widget-grid overview (Datadog-style) on a single scrollable page | High information density; power users love it. | Punishes new users; hard to author for an evolving metric set; performance overhead on mobile. | ❌ Defer until the metric set stabilises. |
| Session-timeline-first (Embrace-style) | Excellent for "why was this one run weird?". | Inverts the priority: makes triage harder; we have far fewer "sessions" than Embrace does. | ❌ Borrow only the Drill idea. |
| Two-pane master-detail (Organizer-style) | Familiar; great on iPad. | On iPhone collapses to push navigation anyway, so the two-pane affordance is wasted. Forces an artificial split. | ❌ Use push navigation on all sizes; allow a `NavigationSplitView` opt-in on iPad later. |

### 3.2 Screen contracts

- **Overview.** Sorted list of metrics; each row shows: current p50/p95, delta
  vs baseline, and a one-line trend sparkline. Filter chips at the top apply
  across all rows. Default sort: "biggest p95 regression vs baseline".
- **Metric.** Trend chart with p50 / p95 / p99 bands, distribution histogram
  underneath, and a sample table. Cohort/tag/build facets in a sticky filter
  bar. "Compare" button → Comparison; tap any sample row → Drill.
- **Comparison.** Two columns or two-series overlay for the same metric
  across two selected cohorts or builds. Always show baseline; never hide it.
  Surface "% change in p95" as the headline KPI.
- **Drill.** Single sample. Envelope dump (all captured attributes), tags,
  cohort, build, and a "neighbours" strip showing other samples that match
  the same tag/cohort within ±N minutes.

### 3.3 Governance context

Dashboard context may include structured performance change notes validated by
the BenchmarkKit preflight described in [`../README.md`](../README.md). These
notes help reviewers answer "what changed near this benchmark window?" without
claiming causality for benchmark movement.

- **Benchmark-impact notes** link to registered suite, scenario, or metric
  IDs and can appear beside related comparisons or drill details.
- **No-impact notes** document nearby work that does not affect measured
  benchmark behavior; they should stay short so unrelated work is not forced
  into long performance narratives.
- **Escape-hatch notes** explain why a change cannot be represented as either
  benchmark-impact or no-impact context, such as generated integration
  metadata or external-only review material.

The UI should render all three as review context, never as proof that a change
caused a regression or improvement.

---

## 4. Chart vocabulary

The dashboard uses a small, deliberate chart palette.

### 4.1 Comparison

- **Side-by-side bars with delta label** for paired metrics on two cohorts /
  builds. Always render baseline first; delta colour is neutral when within
  ±5%, warning when ±5–15%, error when >15%. The thresholds are illustrative
  and configurable; do not hard-code colours into the data layer.

### 4.2 Trend

- **Line chart with p50 / p95 / p99 bands.** p50 is solid; p95 is a shaded
  envelope; p99 is a dashed line. Wall-clock x-axis when the cohort spans
  multiple builds; build-number x-axis when filtered to a single channel.
- **Annotation markers** for build cutovers and known events (e.g. "release
  X.Y shipped"); markers are data-driven so the implementation does not
  hard-code product specifics.

### 4.3 Distribution

- **Histogram with p95 / p99 markers.** Mandatory on Metric and Drill;
  surfaces bimodality that a percentile readout hides.
- **Heatmap (distribution over time)** for the Metric screen when the cohort
  spans >7 days. Each column is a time bucket; cell shade is sample density;
  overlaid line traces p95. Lifted directly from Datadog RUM (§2.5).

### 4.4 Sparklines

- **One-line trend sparklines** on Overview rows. No axes; tooltip on tap
  shows current value and delta. Sparklines must degrade gracefully when
  fewer than `N` samples are available (see §6, empty patterns).

---

## 5. Filter affordances

A persistent filter bar lives at the top of every screen. The bar is the same
component across screens; state is scoped per screen but defaults inherit from
Overview so that drilling does not silently widen the filter.

### 5.1 Envelope facets

The "envelope" is the captured metadata BenchmarkKit attaches to every sample
(build, device class, OS version, locale, thermal state, etc.). Envelope
facets render as **multi-select chips** with a count badge per option.
Empty-selection means "all". This mirrors Firebase Performance and Sentry.

### 5.2 Tags

Tags are call-site annotations on a capture (e.g. `flow:onboarding`,
`feature:export`). Render as a **typeahead search field** because the tag
vocabulary grows over time and chip lists become unwieldy. Borrowed from
Sentry's `tags:` query language; keep the UX simple — no boolean operators in
v1.

### 5.3 Cohorts

Cohorts are pre-defined groupings (e.g. "all builds in last 7 days",
"production only", a saved filter). Render as a **single-select segmented
control** at the top of the filter bar. Cohorts can be saved from any filter
combination; this is borrowed from Sentry saved searches.

### 5.4 Build / version

A dedicated control because it is the most-used facet. Render as a
**range slider over build numbers** on Metric and Comparison; a
**single-select dropdown** on Drill.

### 5.5 Comparison-specific affordances

Comparison adds a second axis: "compare *this* against *that*". The picker is
a two-column sheet — left column "A", right column "B" — pre-populated with
the most recent build vs the previous build. Pulled from Datadog RUM's
compare-overlay pattern.

---

## 6. Empty, loading, and error patterns

Every chart and table must specify three non-happy states. The dashboard
adopts the following conventions, drawn from across the surveyed tools.

### 6.1 Empty

- **No samples in cohort:** show a single-line message ("No samples match
  this filter") plus a *secondary action* that widens the filter by one step
  (e.g. "Show all builds"). Do **not** render a skeleton chart; an empty
  axis is more confusing than a clear empty state.
- **Below-threshold sample count:** when 1 ≤ count < `minRenderThreshold`,
  render the raw values as a small table instead of a chart. Percentile
  bands are meaningless under small `n`.

### 6.2 Loading

- **First load:** skeleton with the chart's axis frame visible, content
  shimmered. Skeleton must match the final chart's bounding box so the
  layout does not jump.
- **Subsequent loads (filter change):** dim the existing chart at ~40%
  opacity and overlay a small spinner; do not blank the chart. Borrowed
  from Datadog and Sentry; the principle is "never lose the user's last
  context to a refresh".
- **Long load (>2s):** swap the spinner for a progress indicator with the
  text "Aggregating samples". This is honest about what is slow and stops
  users from suspecting a hang.

### 6.3 Error

- **Recoverable (network, transient):** inline banner above the chart with
  a "Retry" action. Chart shows the last successful snapshot dimmed.
- **Schema / data-shape error:** replace the chart with an error card that
  includes the failed metric id and a "Copy diagnostics" action. Do not
  show partial data — partial data on a percentile chart is
  silently wrong.
- **Permission / auth:** full-screen error with a single CTA; this is a
  state where the dashboard *cannot* recover on its own.

---

## 7. Open questions for T-R004

These are explicitly **out of scope** for this research artifact but should be
resolved during the SwiftUI implementation:

1. Charting library choice (Swift Charts vs custom Canvas). Swift Charts
   covers §4.1–§4.3 cleanly; the heatmap may require a `Canvas` fallback.
2. iPad split-view adoption. The §3.1 verdict defers this; revisit once the
   Overview metric count exceeds ~12.
3. Whether Drill should support inline annotation editing (Embrace-style) or
   stay read-only in v1.
4. Persistence model for saved cohorts (local vs synced).

---

## 8. Acceptance-criteria checklist

- [x] At least five external references named, each with an annotated note
  under `assets/` (§2.1–§2.5; §2.6 supplementary).
- [x] Canonical navigation pattern chosen: **Overview → Metric →
  Comparison → Drill**, with tradeoffs in §3.1.
- [x] Chart vocabulary covers comparison, trend, and distribution with
  p95 / p99 bands (§4).
- [x] Filter affordances cover envelope facets, tags, and cohorts (§5).
- [x] Empty / loading / error patterns specified per chart (§6).
- [x] Document renders without external assets that fail to load: all
  references are textual notes under `assets/`, no remote image links.
