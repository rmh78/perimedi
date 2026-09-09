# Doctor visit PDF

On-device visit summary PDF from More. Not a new tab. Not on Cycle. Range picker, then in-app preview, then share.

## Sub-features

- More row (`more.sharePdf`) opens the cycle picker
- Cycle picker (`visit.range`) — pick a completed cycle, optional previous, Continue
- In-app preview (`visit.pdf.preview`) with Share (`visit.pdf.share`)

## How to get to it (user POV)

Bottom bar → More → Doctor visit → View PDF → pick cycle(s) → Continue → preview → Share.

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| View PDF | `more.sharePdf` | `testMoreRemindersControls` scrolls, waits, taps. Opens `visit.range`, not the system share sheet. |
| Range sheet | `visit.range` | After tapping View PDF. |
| Cycle row | `visit.range.cycle.{start}` | `A11yID.visitRangeCycle(_:)` → `visit.range.cycle.{start}`. Catalog with sample waits `visit.range.cycle.2026-02-02`. |
| Include previous | `visit.range.previous` | Toggle. Shown when the selected cycle has a previous completed cycle. Journey includes the ID string; empty store has no toggle. |
| Continue | `visit.range.continue` | Journey taps it. |
| Preview | `visit.pdf.preview` | After Continue. Stay in PeriMedi. |
| Share on preview | `visit.pdf.share` | Journey waits. Do not tap — system share sheet has no PeriMedi IDs. |

PDF contents (range, taken rate, symptom table, Effect vs in-range changes, disclaimer) are domain-tested.

## Gotchas

- Do not tap `visit.pdf.share` in journeys (system share sheet).
- Empty store: range sheet copy says 4-week / 12-week fallback; Continue still opens a preview.
- Screen catalog: `more-sample-*`, `visit-range-sample-*`, `visit-pdf-sample-*`. Review Files changed, not PR comment galleries.
- Missing symptom days are not 0. `hot_flash` is days scored. German pump unit is Hub.
- If Effect would name a dose change outside the chosen range, the PDF omits that Effect sentence.
