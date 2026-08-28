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

**There are no accessibility identifiers on these rows.** `MoreView` backup actions are title/body/label copy only (`more.sampleTitle`, `more.exportTitle`, `more.importTitle`, `more.clearTitle`) plus confirm prompts.

Until IDs exist, do not drive backup from XCUITest. Copy-based taps break under de. If you need this surface in the harness, add IDs to `A11yID` and attach them on the backup rows / confirm buttons (`confirm.delete` / `confirm.action` / `confirm.cancel` are already defined).

UI tests never pass `-loadSample`. Sample load is a user action on More, not a launch flag.

## Gotchas

- Clear and sample-load confirm. Destructive. Don't click them in a journey that still needs the store.
- Import/export go through the system document/share sheets (no PeriMedi IDs).
- Domain codec: `ios/Sources/PeriMediDomain` (`ExportPayload` v1). Persistence is the only writer of logs.
