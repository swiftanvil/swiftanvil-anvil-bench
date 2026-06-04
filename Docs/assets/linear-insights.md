# Linear — Project / Cycle insights (annotated notes)

Supplementary reference for `dashboard-ia.md` §2.6. Textual annotation only.

## Layout

- **Cycle progress:** a single chart per cycle. Two thin lines: actual
  progress (solid) and **expected progress** (faint, behind). A tooltip on
  hover reveals raw counts.
- **Project insights:** similar two-line idiom but over a longer horizon;
  baseline is the *plan* line; actuals overlay it.

## Patterns to borrow

1. **Baseline-always-visible.** The baseline ("expected" / "scope") line is
   never hidden behind a toggle. Comparison screens in BenchmarkKit should
   follow suit (§3.2): baseline is always rendered, never optional.
2. **Visual minimalism.** Two lines, faint grid, a single hover-tooltip
   table. A small palette is calmer to scan than a stacked or coloured
   chart, especially when the headline KPI is delta, not absolute.

## What does *not* translate

- Cycle / sprint framing — Linear is a project tool, not a performance
  tool. The visual treatment is what we borrow, not the data model.
