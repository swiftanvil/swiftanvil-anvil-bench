# BenchmarkKit — Cross-device aggregation design

> **Status: implementation deferred.**
> This document is a follow-up design artifact captured during the BenchmarkKit
> extension train (Umbrella D, T-R005). **No code, capabilities, entitlements,
> or imports are added by the issue that introduces this document.** It exists
> so the work isn't lost when picked up later.

## Why this is deferred

The BenchmarkKit extension train explicitly ships Umbrellas A–C only:

- Capture core (envelope + run model).
- Identity & cohorts (`BenchmarkCohort`, comparison cohort filter state).
- Dashboard IA reset (Overview / Metric Drill / Cohort Compare).

Cross-device aggregation introduces three new concerns the current train
deliberately avoids: a network transport, an account-bound identity, and a
privacy classification beyond on-device. Designing it here keeps the door open
without coupling it to the A–C release.

## Goal when picked up

Make a single user's benchmark history visible across their devices, in a way
that lets the Cohort Compare screen distinguish *"this device, last release"*
from *"my other device, last release"* without ever leaking raw identifiers.

Non-goals that should stay non-goals:

- Cross-**user** aggregation, leaderboards, or fleet-wide percentiles.
- Server-side ingestion of full sample streams (the `deep` profile retains raw
  traces and must remain on-device).
- Any transport that requires a Turnip-operated backend.

## Candidate transport: iCloud (CloudKit private database)

The default candidate is **CloudKit private database** on the user's iCloud
account. Rationale:

- **No Turnip-operated backend.** Aggregation is opt-in and lives entirely in
  the user's iCloud — there is nothing to operate, audit, or breach on our
  side.
- **Account-scoped by construction.** Records are unreachable to other users by
  design; we never need to manage an account hash for *access control*, only
  for *cohort labeling*.
- **First-class iOS/macOS support.** No third-party SDK, no extra entitlements
  beyond the iCloud + CloudKit capability the host app would add when picking
  this up.
- **Sync semantics we can live with.** CKQuerySubscription + CKFetchChanges
  cover the "pull peers' summaries when the dashboard opens" pattern; we don't
  need real-time push.

Alternatives considered, why rejected (for the first cut):

- **iCloud Drive / NSUbiquitousKeyValueStore.** KV store is too small and Drive
  gives us files-on-disk, not queryable records. Either could host the same
  data but the dashboard would have to reimplement query/sort.
- **Custom HTTPS endpoint.** Adds an operated service, a privacy review for
  account hashing, and a deletion contract. Not worth it for a developer-/QA-
  facing dashboard.
- **Shared CloudKit container.** Would enable cross-user comparison but
  violates the "no raw identifiers, no cross-user reach" rule below.

## Schema lift from `BenchmarkEnvironment` + summarized system metrics

The aggregation record is a **summary-only** projection of the locked Umbrella A
envelope. Raw `BenchmarkSystemSample` arrays and MetricKit payload bytes are
**never** uploaded — only the `BenchmarkSystemSummary` percentiles. The fields
below are named to map 1:1 onto the existing types in
`BenchmarkKit/Sources/BenchmarkKit/BenchmarkEnvironment.swift`.

### Record: `BenchmarkRunSummaryRecord`

Record type name in CloudKit: `BenchmarkRunSummary`. One record per completed
run, owned by the producing device.

Identity & provenance:

- `runID: String` — UUID of the producing `BenchmarkRun`. Stable across syncs.
- `recordedAt: Date` — wall-clock start of the run window.
- `producingDeviceID: String` — opaque per-install identifier (UUID generated
  on first launch, persisted to the keychain with `kSecAttrSynchronizable=false`).
  Not a hardware identifier and not derivable from one.
- `accountHash: String` — see "Privacy classification" below.
- `cohortID: String` — the `BenchmarkCohort.id` for the run.
- `cohortLabel: String` — the user-visible cohort label captured at run time
  (e.g. `"v26.5.3 / Release"`), for dashboard display without an extra fetch.

Environment lift (mirrors `BenchmarkEnvironment`):

- `deviceModel: String`
- `cpuClass: String`
- `totalPhysicalMemoryBytes: Int64` (CloudKit lacks `UInt64`; clamp on encode)
- `osVersion: String`
- `osBuildNumber: String`
- `bundleShortVersion: String`
- `bundleBuildNumber: String`
- `gitSHA: String?`
- `scheme: String?`
- `isSimulator: Bool` — records flagged `true` are excluded from Cohort Compare
  by default.
- `benchmarkKitVersion: String` — already on `BenchmarkEnvironment`; used to
  reject summaries produced by a record schema this client doesn't understand.
- `localeIdentifier: String`
- `timeZoneIdentifier: String`

Sampling profile & summary lift (mirrors `BenchmarkSystemSummary` +
`BenchmarkSignalSummary`):

- `samplingProfile: String` — `"light"` or `"deep"`.
- `sampleCount: Int`
- For each summarized signal — `residentMemoryBytes`, `memoryFootprintBytes`,
  `availableMemoryBytes`, `cpuUsageFraction`, `batteryLevel`, `freeDiskBytes`,
  `gpuUsageFraction` — a six-field group: `…Min`, `…Peak`, `…Avg`, `…P50`,
  `…P95`, `…P99`. Absent signals are encoded as missing fields, not zero, so a
  later client can distinguish "no data" from "all zeros".

Host-supplied extras:

- `extras: [String: String]` — flattened from `BenchmarkEnvelope.extras`, with
  the following filter applied at upload time:
  - drop any key whose value matches a 32+ hex-digit pattern (treated as a raw
    identifier);
  - drop any key explicitly named in a deny-list (`"userID"`, `"email"`,
    `"deviceUDID"`, etc.) regardless of value;
  - cap total extras size at 1 KB.

What is **deliberately not** in the record:

- `[BenchmarkMetricKitPayload]` raw `jsonData` — too large and contains
  diagnostics CloudKit's private DB isn't the right home for. If aggregated
  diagnostics ever matter, they belong in a separate doc and a separate
  transport.
- Raw `BenchmarkSystemSample` arrays.
- The full `BenchmarkRun` (operations / annotations) — those stay on-device.

### Subscription & query shape

- One `CKQuerySubscription` per device, fired when peer records appear.
- Dashboard's Cohort Compare fetches with predicates of the form
  `cohortID == %@ AND benchmarkKitVersion == %@` so a schema bump fences off
  incompatible records.
- The Cohort Compare loader keeps its existing baseline-vs-current contract; the
  aggregated peer summaries are an additional source it merges in once peer
  fetch settles.

## Privacy classification

**Tier: user-private, account-scoped, summary-only.**

- No raw identifiers leave the device. `producingDeviceID` is a locally minted
  UUID, not `identifierForVendor`, not a hardware ID.
- `accountHash` is `SHA-256(iCloud-account-record-ID || install-salt)` where
  `install-salt` is 32 random bytes generated on first launch and stored in the
  keychain (non-synchronizable). It is stable for the same user on the same
  install, and it is **not** reversible to the iCloud account. Its only job is
  to let the dashboard say *"this is one of your devices"* vs *"a sibling
  device of yours"* without ever surfacing the underlying account.
- All payloads are summaries. No raw sample streams, no MetricKit JSON bytes,
  no log lines.
- Host extras pass through the filter described above.
- Records are visible only to the user (CloudKit private DB), so this is **not**
  a cross-user disclosure even before our own filtering.

## Retention strategy

- **Producer side:** the producing device is the source of truth. Local
  retention follows whatever capture-core retention BenchmarkKit already
  enforces; uploads happen as a side-effect of run finalization.
- **CloudKit side:** keep the most recent **90 days** of summaries per
  `cohortID`, capped at **500 records per cohort per account**. On each
  successful upload, the producer issues a delete query for records older than
  the window or beyond the cap (oldest-first). This bounds storage without
  needing a server cron.
- **User deletion:** because everything lives in the user's private DB, signing
  out of iCloud or deleting the app's iCloud data via Settings → Apple ID →
  iCloud → Manage Storage purges everything in one user-initiated action. The
  feature should document this and not provide an in-app "wipe my data" button
  that pretends to be authoritative.
- **Schema rev:** when `BenchmarkKitVersion.current` major bumps, old records
  are filtered out by the dashboard query rather than migrated. A future
  document can revisit if/when migration becomes worthwhile.

## Conflict resolution sketch

CloudKit gives us optimistic concurrency by record. The aggregation use case
mostly avoids conflicts because each device only writes its own records, but
three cases need a stance:

1. **Same `runID` written twice.** Should not happen in practice (run IDs are
   UUIDs and we only upload on finalization), but if it does — last-writer-wins
   keyed on `recordedAt`; the later `recordedAt` is treated as authoritative.
2. **Deletion races with a peer fetch.** The fetching device may briefly see a
   record that is about to be removed by the producer's retention sweep. The
   dashboard tolerates this by re-querying on pull-to-refresh; stale records
   self-heal within one fetch cycle.
3. **Schema upgrade in flight.** Producers running an older `benchmarkKitVersion`
   keep writing the old shape until updated; newer consumers ignore records
   with an unrecognized version. There is no in-place migration — the next
   schema rev defines its own record type if needed.

## What lands when this is picked up

A future implementation issue should, at minimum:

1. Add the **CloudKit container + iCloud capability** to the host app target
   (not to the BenchmarkKit package — the package stays transport-agnostic).
2. Introduce a `BenchmarkAggregationPublisher` protocol in BenchmarkKit and
   ship a `CloudKitBenchmarkAggregationPublisher` in a *separate* package
   target (so the core package keeps zero CloudKit dependency).
3. Wire the publisher into the same site that writes runs to disk today, behind
   a host-supplied feature flag.
4. Extend the Cohort Compare loader to merge peer summaries (this is also where
   the *"cohort A/B is UI-only, data path unchanged"* gap noted on issue #130
   should finally close).
5. Add tests that round-trip an envelope → record → envelope projection without
   regressing on the locked Umbrella A fields, and that verify the extras
   redactor drops raw identifiers.

## References

- Umbrella A envelope source of truth:
  `zaps-app/BenchmarkKit/Sources/BenchmarkKit/BenchmarkEnvironment.swift`
- Cohort model:
  `zaps-app/BenchmarkKit/Sources/BenchmarkKit/BenchmarkCohort.swift`
- Dashboard IA:
  `zaps-app/BenchmarkKit/Docs/dashboard-ia.md`
