# Xcode Organizer — Metrics tab (annotated notes)

Reference for `dashboard-ia.md` §2.1. No proprietary screenshot is checked in;
this file captures the layout from observation.

## Layout

- **Left rail:** scrollable list of metric categories.
  - Power: Battery Usage, Disk Writes.
  - Performance: Launch Time, Hang Rate, Scroll Hitches.
  - Behaviour: Crashes, Memory.
- **Top toolbar:** app picker, version picker (default "All Versions"),
  device-class filter (All / iPhone / iPad / specific model), build-channel
  filter (App Store vs TestFlight).
- **Main pane:** per-metric chart.
  - X-axis: **version**, ordered oldest → newest.
  - Y-axis: metric units (ms, %, MB, etc.).
  - Bars: a single bar per version, with internal **p50 / p90 bands**
    rendered as overlaid shading.
  - Below the chart: regression callout ("Worse than previous version") and a
    plain-English explainer ("Your app launched 12% slower on iPhone 15 Pro
    running iOS 17.4 than on the prior version").

## Why it matters for BenchmarkKit

1. **Version-as-x-axis** is the right default for build-channel filtered
   views. Wall-clock time blurs build cutovers and makes A/B reads harder.
2. **Percentile bands inside a bar** — a compact way to surface tail
   behaviour without committing the user to a second chart.
3. **Plain-English regression callout** is a great pattern to lift verbatim
   for the Overview screen.

## What does *not* translate

- The strict "App Store only" data scope. BenchmarkKit captures from any
  build channel; do not hide TestFlight or local builds by default.
- The two-pane layout. On iPhone it collapses; see `dashboard-ia.md` §3.1.
