# Embrace (annotated notes)

Reference for `dashboard-ia.md` §2.4. Textual annotation only.

## Layout

- **Performance overview:** session counts split by outcome (clean / hang /
  crash / ANR analogue), rendered as a stacked area chart over time.
- **User timelines:** the signature screen. A single user session is a
  vertical timeline with timestamped events (screen loads, network calls,
  custom logs, errors). Annotations sit alongside the timeline.
- **Cohort selector:** persistent across screens. Cohorts include user tier,
  app version, device class, country, custom session attributes.

## Patterns to borrow

1. **Session-timeline drill.** Even though BenchmarkKit captures samples, not
   sessions, the *idea* of a vertical, annotated timeline with neighbouring
   events is the right Drill-screen pattern (§3.2).
2. **Cohort-first navigation.** A persistent cohort selector reduces filter
   thrash. Translates to the cohort segmented control in §5.3.
3. **Outcome-stacked area chart.** For BenchmarkKit, the analogue is
   "samples that passed the budget vs samples that did not".

## What does *not* translate

- Session-as-primary-unit. BenchmarkKit's primary unit is the sample, with
  build/cohort as the grouping. Borrow the drill aesthetic, not the IA
  hierarchy.
