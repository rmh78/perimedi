# Symptom sheet

Structured scores (1–4) plus optional note. Untouched catalog ids stay missing (not stored as 0). Presented over Cycle.

## Sub-features

- Per-symptom score buttons
- Optional body/note field
- Close (first-use saves by closing; `symptom.save` exists on the ID list)

## How to get to it (user POV)

Cycle → + Symptom (`cycle.action.symptom`).

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| Sheet | `sheet.symptom` | Present after `cycle.action.symptom`. |
| Close | `sheet.close` | First-use path: tap scores, then close. Sheet gone. |
| Score | `symptom.score.{id}.{1-4}` | First-use: `hot_flash` 3, `sleep` 2, `joints` 1. |
| Body / note | `symptom.body` | Optional. |
| Save | `symptom.save` | In `A11yID`. First-use uses close, not this. |

After logging, Cycle shows `cycle.chip.score.{id}`. Hot flash 3 in en: value contains `strong`.

`AppRobot.addSymptom()` is the packaged path.

## Gotchas

- Catalog ids are snake_case (`hot_flash`), not the display name.
- Severity 1–4. Do not write 0 for "untouched".
- `cycle.chip.score.{id}` is assembled in `CycleView`, not listed on the `A11yID` enum.
