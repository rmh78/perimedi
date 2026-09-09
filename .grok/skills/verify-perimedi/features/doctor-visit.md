# Doctor visit PDF

On-device visit summary PDF, shared from More. Not a new tab. Not on Cycle.

## Sub-features

- Share PDF (`more.sharePdf`) — generates a PDF and opens the iOS share sheet

## How to get to it (user POV)

Bottom bar → More → Doctor visit → Share PDF.

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| Share PDF | `more.sharePdf` | `FirstUseJourneyTests.testMoreRemindersControls` scrolls to it and waits. Do not tap — system share sheet has no PeriMedi IDs. |
| Catalog PDF page | `visit.pdf.preview` | `ScreenCatalogTests` only (`-loadSample -catalogVisitPdf`). First page of the sample visit PDF. Not the journey. |

PDF contents (range, taken rate, symptom table, disclaimer) are domain-tested, not asserted from the share sheet.

## Gotchas

- Same share-sheet pattern as JSON export. Journey waits; it does not tap.
- Screen catalog More shots scroll to `more.sharePdf` so the entry is in `ios/docs/screens/more-sample-*.png`. Sample PDF first page is `visit-pdf-sample-en.png` / `visit-pdf-sample-de.png` (`-catalogVisitPdf`). Review Files changed, not PR comment galleries.
- Range is last 1–2 completed cycles, or 4-week / 12-week fallback. Missing symptom days are not 0. `hot_flash` is days scored.
