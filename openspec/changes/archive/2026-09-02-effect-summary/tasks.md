## 1. Domain model and backup

- [x] 1.1 Add `MedicationChange` and optional `medicationChanges` on version-1 `ExportPayload` (missing list decodes as empty)
- [x] 1.2 Diff helper: one event per actually changed dose or primary schedule; new med has empty previous; unchanged save writes nothing
- [x] 1.3 Include change events in `BackupCodec.makeExport` and sample payload (one dose change in the current or previous cycle)

## 2. Effect comparison

- [x] 2.1 Cycle-aligned windows from logged period starts; today as N; no rolling 7-day window; tracking off → hidden
- [x] 2.2 Means from scored ids in both windows only; missing is not 0; kinds: no previous cycle, not enough days, similar, changed (max 3 shifts)
- [x] 2.3 Attach at most one in-span change as context (prefer dose); ignore changes outside the two cycles

## 3. Persistence and capture

- [x] 3.1 SwiftData model + schema; `Store` snapshot, refresh, wipe, import, export
- [x] 3.2 Medication sheet: optional Since date when dose/schedule changed; save writes events through Store

## 4. Cycle UI and i18n

- [x] 4.1 Effect sentence on Cycle with `cycle.effect`; EN/DE copy; no medical advice
- [x] 4.2 Feature map + `A11yID` (`cycle.effect`, `med.since`)

## 5. Tests and doctor

- [x] 5.1 Domain tests for change events, backup round-trip/older backup, and Effect scenarios
- [x] 5.2 `bash ios/scripts/verify.sh`
