# Datadog RUM (annotated notes)

Reference for `dashboard-ia.md` §2.5. Textual annotation only.

## Layout

- **Application overview:** scrollable single-page dashboard composed of
  widgets. Every widget has the same control header: metric selector,
  aggregation (avg / p75 / p95 / p99), grouping, filter.
- **Widget vocabulary:**
  - Time-series line.
  - Top-N table with delta column.
  - **Distribution heatmap** (x = time bucket, y = value bucket, cell shade
    = sample density), often with a p95 line overlaid.
  - Top list (sorted bars).
- **Drill:** side panel that slides in from the right, preserving the
  widget grid behind it. The panel shows the breakdown for the clicked
  point/row.
- **Compare overlay:** the same time series rendered twice, one per
  release / environment, with a delta band between them.

## Patterns to borrow

1. **Persistent filter bar** at the top of every screen — borrowed for §5's
   envelope facets.
2. **Distribution heatmap over time** — borrowed for §4.3 (Metric screen
   when the cohort spans more than ~7 days).
3. **Side-panel drill.** Keeps context. Worth considering for iPad layouts
   in T-R004 even though the iPhone navigation stays push-based.
4. **Compare overlay** — borrowed for §3.2's Comparison screen.

## What does *not* translate

- The widget-grid Overview itself. Powerful but high-friction on mobile and
  premature while the metric set is still evolving (see §3.1 tradeoff
  table).
- Datadog's query syntax. Keep BenchmarkKit's filter language declarative,
  not free-text.
