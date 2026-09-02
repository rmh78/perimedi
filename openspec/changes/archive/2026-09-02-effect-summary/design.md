## Context

See proposal.md for why. Symptom scores, periods, and medication saves already exist. Cycle has no comparison copy. JSON backup is `ExportPayload` version 1 with optional lists (`symptomScores` already optional). `Store` is the persistence writer; domain math lives in `PeriMediDomain`.

## Goals / Non-Goals

**Goals:**

- Domain-owned comparison and change-event diff so the app does not invent cycle math in SwiftUI.
- Persist events in SwiftData and round-trip them in version-1 JSON without bumping version.
- One sentence on Cycle; optional since-date on the existing medication sheet.

**Non-Goals:**

- PDF, Trends chart, widgets, HealthKit, flattening nested schedule JSON, CloudKit refresh (#19).
- Episode counts for hot flushes.
- A new primary screen.

## Decisions

### 1. Structured domain result, localized in the app

`EffectLogic` returns a kind (`hidden`, `noPreviousCycle`, `notEnoughDays`, `similar`, `changed`) plus optional overlapping symptom shifts and at most one context change. Cycle maps that to `L10n` keys. Domain tests assert kinds and ids, not English strings.

Alternative: domain emits English and German. Rejected — chrome localization stays in `L10n`.

### 2. Comparison uses today, not the selected Cycle day

The sentence is a payoff for logging, not a historical replay while paging. Windows are cycle days 1…N of **today’s** logged cycle vs the same numbers of the previous logged cycle. Predicted starts do not define cycles. Period tracking off → `hidden`.

Cycle-day overlap is the intersection of days that exist in both cycles (a short previous cycle does not invent days).

Mean severity per id in each window; missing days omitted. An id qualifies only if both windows have at least one score. Direction: mean delta ≥ 0.5 worse, ≤ −0.5 improved, else similar for that id. Sentence lists at most three largest-magnitude shifts in catalog order.

### 3. `MedicationChange` events, JSON key `medicationChanges`

Fields: id, medicationId, nameSnapshot, field (`dose` | `schedule`), previousValue, newValue, effectiveDate, loggedAt. Version stays 1; missing key decodes as `[]`. Store never invents rows on import.

Schedule snapshots are compact, language-independent (`every day @ 08:00`, `days 1,4 @ 21:30`, `14/14 @ 21:00`) so backup is stable. Sentence context uses name + field (“Since the new {name} dose:”) and prefers a dose event over schedule when both sit in the two-cycle span; otherwise the latest effective date in that span.

Diff runs in domain (`MedicationChangeLog`) from previous med+primary schedule vs saved. One event per actually changed field. New medication: empty previous. Unchanged save: no events. Sheet is the only capture; `Store.appendMedicationChanges` is the writer.

### 4. Effective date on the medication sheet

When dose or schedule actually differs (including a new med), show a compact “Since” date, default today. Hidden when nothing changed. Not a new page.

### 5. Sample payload includes overlapping scores and one dose change

So loading sample on a typical today (cycle day 18) yields a real sentence plus dose context, without the UI tests needing sample load.

## Risks / Trade-offs

- [Sparse scores] → empty “not enough days” is correct; do not treat missing as 0.
- [Mean threshold 0.5] → small noise stays “similar”; one full step still counts.
- [Schedule snapshot is not localized] → values in backup/events stay machine-stable; the sentence does not print the snapshot, only name + field.
- [Change events survive med delete] → name snapshot still works for context; wipe/import still replace the list.

## Migration Plan

No schema version bump. New SwiftData model with defaults (CloudKit-safe). Older backups omit `medicationChanges`. Unsigned Simulator stays local-only.

## Open Questions

None that block implementation.
