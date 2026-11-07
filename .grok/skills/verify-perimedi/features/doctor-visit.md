# Doctor visit PDF

On-device visit summary PDF from More. Not a new tab. Not on Cycle. Range picker, then in-app preview. Back returns to that same picker. Close and the dimmed backdrop leave both and show More.

## Sub-features

- More row (`more.sharePdf`) opens the cycle picker
- Cycle picker (`visit.range`). Pick a completed cycle, optional previous, then Continue. Cancel dismisses to More. No Back on this sheet.
- In-app preview (`visit.pdf.preview`) with Share (`visit.pdf.share`) and Back (`visit.pdf.back`)

## How to get to it (user POV)

Bottom bar → More → Doctor visit → View PDF → pick cycle(s) → Continue → preview. Back returns to the same cycle choice. Share opens the system sheet. Close, or a tap on the dimmed backdrop, dismisses the picker and the preview and shows More.

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| View PDF | `more.sharePdf` | `testUserFlow` scrolls, waits, taps. Opens `visit.range`, not the system share sheet. |
| Range sheet | `visit.range` | After tapping View PDF. |
| Cycle row | `visit.range.cycle.{start}` | `A11yID.visitRangeCycle(_:)` → `visit.range.cycle.{start}`. Value `on` or `off`. Catalog with sample waits `visit.range.cycle.2026-02-02` before any row change. After the preview picture, Back, it taps a row whose value is `off`, continues, taps Back, and that row is `on` while the row that was `on` is `off`. It does not name a start date. |
| Include previous | `visit.range.previous` | Toggle. Shown when the selected cycle has a previous completed cycle. `testUserFlow` reaches More with one period and does not wait for this toggle. Catalog with sample waits `visit.range.cycle.2026-02-02`. |
| Continue | `visit.range.continue` | Journey taps it. |
| Preview | `visit.pdf.preview` | After Continue. Stay in PeriMedi. |
| Share on preview | `visit.pdf.share` | Journey waits. Do not tap. The system share sheet has no PeriMedi IDs. |
| Back | `visit.pdf.back` | Preview footer, left of Share, on the same equal-width row. The word stays Back. `testUserFlow` taps it. `visit.range` is present and `visit.pdf.preview` is gone, with the same choice restored. The range sheet has no Back. Its left button is Cancel and dismisses to More. Close (`sheet.close`) and the dimmed backdrop dismiss both and show More. |

PDF contents (range, taken rate, symptom table, Effect vs in-range changes, disclaimer) are domain-tested.

## Gotchas

- Cycle rows and PDF period rows use `DateCopy.closed`, the same medium date pair as period history. Single dates in the PDF and the range-header words use `DateCopy.day`.
- Do not tap `visit.pdf.share` in the user flow. The system share sheet has no PeriMedi IDs.
- Empty store, and one open period, have no cycle row. The picker shows the empty-cycle sentence. Continue still opens a preview. Back returns that picker. The user flow proves the empty return. The catalog proves the choice survives Back.
- Screen catalog: `more-sample-en`, `visit-range-sample-en`, `visit-pdf-sample-en`. Review Files changed, not PR comment galleries.
- Missing symptom days are not 0. `hot_flash` is days scored. German pump unit is Hub, and a decimal in that dose or in a mean is a comma.
- If Effect would name a dose change outside the chosen range, the PDF omits that Effect sentence.
