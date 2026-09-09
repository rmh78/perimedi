## Context

See proposal.md for why. Effect (#20) and Trends (#28) are on `main`. Visit PDF is GitHub #23. Domain already owns cycle windows (`CycleLogic.loggedCycleWindows`), planned-dose expansion (`ScheduleLogic.expandPlannedDoses`), Effect (`EffectLogic.summarize`), and symptom day-count/mean (`SymptomTrendLogic`). More already shares JSON via `UIActivityViewController`. JSON backup stays version 1.

## Goals / Non-Goals

**Goals:**

- Domain-owned range, taken-rate, symptom-table, and PDF bytes so the app does not reimplement cycle math.
- One More action + existing share-sheet pattern.
- Domain tests that a dummy range with scores, periods, meds, and one dose change appears in the extracted PDF text.

**Non-Goals:**

- New tab, Cycle control, Trends/Effect redesign, MRS text, episode counts, HealthKit, widgets, backup schema bump, #43 L10n split.

## Decisions

### 1. Completed cycles drop the open window that ends today

`loggedCycleWindows` always ends the last window on today. That last window is the current (incomplete) cycle. Completed cycles are `dropLast()`. Two completed → last two; one completed → that one; none → calendar fallback.

**4-week vs 12-week:** one logged start (open cycle only) → last 28 days including today. No starts, or period tracking off → last 84 days including today. Tracking off ignores leftover period rows so the PDF does not pretend month-mode days are cycles.

Alternative: include the current incomplete cycle in the default range. Rejected — the issue asks for completed cycles, with calendar fallback when history is thin.

### 2. Structured report, localized in the app, PDF bytes in domain

`DoctorVisitLogic.report` returns date keys, range kind, med taken counts, overlapping periods, in-range changes, symptom rows (catalog order, severity ≥ 1 only), and the current `EffectResult`. The app maps that to a `DoctorVisitPage` (L10n + locale dates + Effect sentence). `DoctorVisitPDF.data(page:)` draws Core Text into a PDF so domain tests can extract strings with PDFKit on macOS.

Alternative: UIKit `UIGraphicsPDFRenderer` only in the app. Rejected — then dummy-range content is not asserted without a Simulator.

### 3. Taken rate is taken / planned in the range

Planned doses come from `ScheduleLogic.expandPlannedDoses` over the report range. Taken rate is count of `.taken` divided by planned count. Pending and skipped count as not taken. Medications with zero planned doses in the range are omitted.

### 4. All in-range changes, Effect sentence as on Cycle

List every stored dose/schedule change whose effective date is in the range, oldest first, labeled as context only. Effect uses `EffectLogic.summarize` for **today** (same as Cycle), not a replay of the PDF range. Hidden → omit the Effect block.

### 5. Symptom table reuses Trends counting rules, not the chart

Per catalog id in the range: distinct days with severity ≥ 1, mean of those severities. Omit ids with no scores. Ignore `SymptomScore.count` so `hot_flash` stays days scored. No plot, no eleven-row graphic, no MRS wording.

### 6. More-only share, same sheet as JSON export

One card between Reminders and Backup. Write `perimedi-visit.pdf` in the temp directory and present the existing share sheet. Tests wait for `more.sharePdf` and do not tap (system sheet has no PeriMedi IDs), matching export. Screen catalog scrolls the More shot to that control.

## Risks / Trade-offs

- [Sparse period history] → 4-week / 12-week fallback is explicit on the PDF range line.
- [Empty store] → PDF still generates (twelve-week empty sections + disclaimer) so share never no-ops.
- [Share sheet in UI tests] → wait for the control, do not tap.
- [PDF pagination] → Core Text framesetter + extra pages; tests join all page strings.

## Migration Plan

No schema change. Unsigned Simulator stays local-only. Rollback is revert; no stored visit files.

## Open Questions

None that block implementation.
