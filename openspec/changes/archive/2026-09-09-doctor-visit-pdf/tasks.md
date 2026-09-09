## 1. Domain report and PDF

- [x] 1.1 Add `DoctorVisitLogic.report` (completed-cycle range, 4-week/12-week fallback, taken rates, in-range changes, overlapping periods, symptom table, Effect result)
- [x] 1.2 Add `DoctorVisitPage` + `DoctorVisitPDF.data` (Core Text PDF, paginated)
- [x] 1.3 Domain tests: two/one completed cycles, 4-week and 12-week fallbacks, tracking off, missing ≠ 0, hot_flash days scored, dummy range PDF text, disclaimer
- [x] 1.4 Register the new math in `check-domain-boundary.py` and call it from the app

## 2. More action and copy

- [x] 2.1 Extract Effect sentence helper so Cycle and the PDF share the same copy
- [x] 2.2 EN+DE L10n for More action and PDF chrome; disclaimer not a medical record / not advice
- [x] 2.3 More card (after Reminders, before Backup) that writes the PDF and opens the share sheet
- [x] 2.4 `A11yID.moreSharePdf`, feature map, More journey wait (do not tap the system sheet)

## 3. Catalog, specs, doctor

- [x] 3.1 Screen catalog More shots include the visit entry; no PR comment galleries
- [x] 3.2 Sync OpenSpec deltas into `openspec/specs/` and archive the change
- [x] 3.3 `bash ios/scripts/verify.sh` green
