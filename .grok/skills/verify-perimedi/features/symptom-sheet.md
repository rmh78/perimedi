# Symptom sheet

Structured scores (1–4). Untouched catalog ids stay missing (not stored as 0). Presented over Cycle. No note field in the sheet.

## Sub-features

- Per-symptom score buttons (tap again clears; persist on each tap)
- Close (does not write; each score tap already saved)
- Custom name field `symptom.custom.add`, Add control `symptom.custom.create`
- Custom row name `symptom.custom.name.{id}`, Rename `symptom.custom.rename.{id}`, save `symptom.custom.save.{id}`, delete `symptom.custom.delete.{id}`
- `symptom.body` / `symptom.save` exist on the `A11yID` enum only — **not attached**

## How to get to it (user POV)

Cycle → + Symptom (`cycle.action.symptom`).

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| Sheet | `sheet.symptom` | Present after `cycle.action.symptom`. |
| Close | `sheet.close` | First-use path: tap scores, then close. Sheet gone. |
| Score | `symptom.score.{id}.{1-4}` | First-use: `hot_flash` 3, `sleep` 2, `joints` 1. Custom rows use the same id shape. |
| Custom name field | `symptom.custom.add` | `testCustomSymptomCreateScoreRenameChartAndDelete` types Brain fog, then Add. |
| Add | `symptom.custom.create` | The new row appears under Custom. The same test waits for `symptom.custom.name.c.`. |
| Custom name | `symptom.custom.name.{id}` | The id is `c.` plus a UUID. After rename the field holds Fog. |
| Rename | `symptom.custom.rename.{id}` | The test taps Rename, types Fog, and the chip no longer contains Brain. |
| Rename save | `symptom.custom.save.{id}` | Saves the new name and keeps the id. The chip then contains Fog. |
| Delete | `symptom.custom.delete.{id}` | The dialog says `Delete Fog and all its past scores?`. Confirm with `confirm.delete`. The custom chip is gone. `cycle.chip.score.hot_flash` still contains `strong`, and reopening the sheet leaves `symptom.score.hot_flash.3` selected. |
| Body / note | `symptom.body` | On the `A11yID` enum only; the sheet has no note field (`persist` always passes `note: nil`). Do not drive it. |
| Save | `symptom.save` | On the `A11yID` enum only. First-use uses `sheet.close`. Do not drive it. |

After logging, Cycle shows `cycle.chip.score.{id}` via `A11yID.chipScore(_:)`. Hot flash 3 in en: value contains `strong`.

`AppRobot.addSymptom()` is the packaged path.

## Gotchas

- Catalog ids are snake_case (`hot_flash`), not the display name.
- Severity 1–4. Do not write 0 for "untouched".
- Keep the `cycle.chip.score.` literal in this map so check-feature-map still sees `A11yID.chipScore`.
