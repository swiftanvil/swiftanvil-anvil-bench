# Sentry Performance (annotated notes)

Reference for `dashboard-ia.md` §2.3. Textual annotation only.

## Layout

- **Performance overview:** table of transactions sorted by a configurable
  column. Default columns: transaction name, project, p50, p95, failure
  rate, throughput, "users misery" score.
- **Transaction summary:** three stacked panels.
  1. Trend chart with a shaded p95 envelope; time range selector at top.
  2. Duration **distribution histogram** with p95 / p99 markers; this is the
     chart that exposes bimodality.
  3. Related-events table with a quick filter and inline tag chips.
- **Event detail:** single trace waterfall. Out of scope for the BenchmarkKit
  dashboard but referenced as the Drill-screen analogue.
- **Trends surface:** a separate screen that ranks transactions by **change
  in p95** across two windows. The crucial idea is sorting by *delta*, not
  *absolute*.

## Patterns to borrow

1. **Trend + distribution stacked on the same screen.** Trend answers "is it
   getting worse?"; distribution answers "is it bimodal or heavy-tailed?".
   Both are needed; neither alone is enough.
2. **`tags:` query language** → BenchmarkKit's tag typeahead (§5.2).
3. **"Trends" ranked by delta** → the Overview default sort (§3.2).
4. **Saved searches** → cohorts (§5.3).

## What does *not* translate

- Sentry's "users misery" scoring; it's product-specific.
- Boolean tag operators in v1 — keep the search simple.
