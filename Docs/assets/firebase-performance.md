# Firebase Performance Monitoring (annotated notes)

Reference for `dashboard-ia.md` §2.2. Textual annotation only.

## Layout

- **Dashboard tab:** four KPI cards across the top (app start, network
  success rate, slow frames %, frozen frames %) with sparkline trend.
- **Traces tab:** sortable table of all named traces (custom + auto).
  Columns: trace name, duration p50, duration p90, sample count, % change vs
  baseline.
- **Trace detail:**
  - Header: current p50 / p90 / p95 with delta vs selected baseline.
  - Time series: line chart over wall-clock with date-range picker.
  - Attribute breakdown: a sorted table where each row is an attribute value
    (e.g. `device: iPhone 14`) with a sparkline showing that subgroup's
    trend.
  - **Issues** pane: auto-detected regressions ("Slow rendering on
    `feature_x`, +18% p90 since version 4.5.0").

## Patterns to borrow

1. **"Group by" attribute drill.** Same metric, different attribute facet,
   side-by-side. Translates to BenchmarkKit's envelope facets (§5.1).
2. **Issues pane** as a complement to the Overview list — surfaces what the
   user *should* be looking at, not just what they sorted to the top.
3. **Date-range picker** as a first-class control on detail screens, not
   buried in settings.

## What does *not* translate

- Firebase's hard cap on custom attributes (5). BenchmarkKit's envelope is
  richer; we should not artificially constrain the facet list.
- The "alerting" surface — out of scope for the dashboard; lives in a
  separate notification path.
