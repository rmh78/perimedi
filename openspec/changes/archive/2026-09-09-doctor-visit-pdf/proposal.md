## Why

After Effect and Trends, the next take-it-with-you step is a visit PDF she can share before a gynecologist appointment. Logging is already on-device; she still has to recap cycles, doses, and symptoms from memory. This is GitHub #23 (priority Now in #27). It is not a medical record and not medical advice.

## What Changes

- One action on **More** generates an on-device PDF and opens the iOS share sheet (Mail, Files, Print). Not a new tab. Not on Cycle.
- The PDF covers a cycle-aligned range: last 1 or 2 **completed** cycles, with a 4-week or 12-week calendar fallback when period history is too thin.
- The PDF includes medications and taken rate, stored dose/schedule changes as context only, periods in the range, the current Effect sentence when one exists, date generated, and a disclaimer (not a medical record, not advice).
- Symptoms are a compact **table** of catalog ids that have scores in the range (days scored + mean intensity). Missing days are not 0. `hot_flash` is days scored. The Trends chart is not copied. No MRS questionnaire text. No PeriMedi server.
- English and German chrome and PDF copy. JSON export / iCloud behavior unchanged.
- `ios/docs/screens/` More catalog pictures include the new entry. No PR comment screenshot galleries.

## Capabilities

### New Capabilities

- `doctor-visit`: On-device visit PDF from More via the iOS share sheet, including range selection, contents, symptom table rules, disclaimer, and language.

### Modified Capabilities

- `ios-app`: More layout gains a doctor-visit action (language, reminders, visit share, backup, privacy).
- `home-surface`: More tools include the visit PDF action, still not a fifth tab.
- `privacy-local-data`: Visit PDF is generated on device and leaves the app only when the user shares it.
- `product-constraints`: PDF copy keeps the not-medical-advice stance and states it is not a medical record.
- `localization`: Visit action and PDF chrome are English and German.
- `ios-ui-tests`: The More visit-share control has a stable identifier and is driven by the More journey; catalog pictures include the More entry.

## Impact

- Domain: range, taken-rate, symptom-table, and PDF payload math in `PeriMediDomain` (no schedule/cycle math in SwiftUI).
- App: More row + share sheet; PDF file written locally then handed to `UIActivityViewController`.
- Feature map, UI tests, screen catalog for More.
- No backup schema bump, no CloudKit change, no Trends/Effect redesign.
