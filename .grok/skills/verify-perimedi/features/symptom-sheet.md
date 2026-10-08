# Symptom sheet

Structured scores (1–4). Untouched catalog ids stay missing (not stored as 0). Presented over Cycle. No note field in the sheet.

## Sub-features

- Per-symptom score buttons (tap again clears; persist on each tap)
- Close (does not write; each score tap already saved)
- Add control `symptom.custom.create` opens one dialog titled New symptom. The name field in that dialog is `symptom.custom.add`. The commit button on that id reads Save
- Underlined custom name `symptom.custom.name.{id}` opens the same dialog titled Edit symptom. Save is `symptom.custom.save.{id}`. Delete is `symptom.custom.delete.{id}`
- `symptom.body` / `symptom.save` exist on the `A11yID` enum only — **not attached**

## How to get to it (user POV)

Cycle → + Symptom (`cycle.action.symptom`).

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| Sheet | `sheet.symptom` | Present after `cycle.action.symptom`. |
| Close | `sheet.close` | First-use path: tap scores, then close. Sheet gone. |
| Score | `symptom.score.{id}.{1-4}` | First-use: `hot_flash` 3, `sleep` 2, `joints` 1. Custom rows use the same id shape. |
| Add | `symptom.custom.create` | Secondary pill below the custom names. The test taps it, types Brain fog into `symptom.custom.add`, and taps Save on the same `symptom.custom.create` id. The dialog title is New symptom. The field stays above the keyboard. |
| Custom name field | `symptom.custom.add` | In the dialog on top of the sheet, for a new name and for a rename. |
| Custom name | `symptom.custom.name.{id}` | Underlined name on the row. The test taps it to open the same dialog, then types Fog. |
| Rename save | `symptom.custom.save.{id}` | Primary pill in that dialog. The dialog title is Edit symptom. The chip then contains Fog. |
| Delete | `symptom.custom.delete.{id}` | On the edit dialog’s button row, between Cancel and Save, same as the period card. That dialog’s contents become `Delete Fog and all its past scores?`. Confirm with `confirm.delete`. The custom chip is gone. `cycle.chip.score.hot_flash` still contains `strong`, and reopening the sheet leaves `symptom.score.hot_flash.3` selected. |
| Body / note | `symptom.body` | On the `A11yID` enum only; the sheet has no note field (`persist` always passes `note: nil`). Do not drive it. |
| Save | `symptom.save` | On the `A11yID` enum only. First-use uses `sheet.close`. Do not drive it. |

After logging, Cycle shows `cycle.chip.score.{id}` via `A11yID.chipScore(_:)`. Hot flash 3 in en: value contains `strong`.

`AppRobot.addSymptom()` is the packaged path.

## Gotchas

- Catalog ids are snake_case (`hot_flash`), not the display name.
- Severity 1–4. Do not write 0 for "untouched".
- Keep the `cycle.chip.score.` literal in this map so check-feature-map still sees `A11yID.chipScore`.
