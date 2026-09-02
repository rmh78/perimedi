## Why

Symptom scores are on `main`, but Cycle still gives no cycle-to-cycle payoff. Without a sentence that uses those scores (and any stored dose change as context), logging does not feel worth it. This is GitHub #20, first in the #27 order, and it unblocks Trends (#28) and the doctor PDF (#23).

## What Changes

- Store an on-device dose/schedule **change event** when a medication save actually changes the default dose or primary schedule (a new medication counts; previous value empty). Optional effective date on the medication dialog (“since …”). Never invent an event.
- Show one **Effect sentence** on Cycle: this cycle so far vs the same cycle days of the previous cycle. Missing scores are not 0. Higher severity is worse. English and German. No rolling 7-day window.
- If a stored change sits in this cycle or the previous one, prefix context with the medication name and new value. Never recommend changing dose. Not medical advice.
- Include the change list in version-1 JSON export/import. Older backups without the list still import.

Out of scope: PDF, HealthKit, widgets, extra symptom fields, MRS questionnaire text, Trends chart.

## Capabilities

### New Capabilities

- `effect-summary`: Cycle-to-cycle comparison sentence and stored dose/schedule change events that may appear as context in that sentence.

### Modified Capabilities

- `medications`: Saving a medication records a change event when default dose or primary schedule actually changed; the dialog may set an effective date.
- `backup-and-sample`: Version-1 export/import includes the change-event list; older backups without it still import; sample data may include events.

## Impact

- `PeriMediDomain`: new change-event model, cycle-window comparison, sentence builder; `ExportPayload` gains an optional list.
- SwiftData `Store` + models: persist change events; medication save is the only writer of events.
- Cycle screen: one localized sentence (or empty-state line).
- Medication sheet: optional effective date when dose/schedule changed.
- Feature map, `A11yID`, domain tests, and `verify.sh`.
- iOS chrome via `L10n` / `Localizable.xcstrings` (en/de).
