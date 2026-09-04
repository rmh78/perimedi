# Backup, sample, clear

JSON backup (`ExportPayload` version 1), load sample, import, clear. Lives on More. Optional visual capture still uses `JourneyScript` / `ios/scripts/shot-journey.sh` (seeded snapshots) — that is **not** interaction proof.

## Sub-features

- Load sample (`SampleData.payload()` via More → Backup)
- Export `perimedi-backup.json`
- Import
- Clear all local data (confirm)

## How to get to it (user POV)

Bottom bar → More → Backup section.

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| Load sample | `more.sample` | `FirstUseJourneyTests.testMoreRemindersControls` waits, taps, then `confirm.cancel`. Sample confirm is not destructive (`confirm.action`, not `confirm.delete`). Do not tap `confirm.action`. |
| Export | `more.export` | Journey waits. Do not tap — system share sheet has no PeriMedi IDs. |
| Import | `more.import` | Journey waits. Do not tap — system document sheet has no PeriMedi IDs. |
| Clear all | `more.clear` | Journey waits. Do not tap. Confirm is destructive (`confirm.delete`). |

`testMoreRemindersControls` waits for all four row IDs (swipe up if below the fold), taps sample, then `confirm.cancel`, then `waitGone` for the confirm card. Do not confirm sample load or clear.

UI tests never pass `-loadSample`. Sample load is a user action on More, not a launch flag.

## Gotchas

- Clear and sample-load confirm. Destructive / wipes store. Tests cancel, never confirm.
- Import/export go through the system document/share sheets (no PeriMedi IDs).
- Invalid backup: existing data is left unchanged and More shows `more.importFailed`. A failed local save/import write shows `persist.saveFailed` and does not publish a snapshot that disagrees with disk.
- Domain codec: `ios/Sources/PeriMediDomain` (`ExportPayload` v1). Persistence is the only writer of logs. iCloud device-switch is `Store.refresh()` on remote import and foreground; JSON export is the fallback when iCloud is off.
