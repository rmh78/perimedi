# Symptom sheet

Structured scores (1–4). Untouched catalog ids stay missing (not stored as 0). Presented over Cycle. No note field in the sheet.

## Sub-features

- Per-symptom score buttons (tap again clears; persist on each tap)
- Close (persists again; first-use uses close)
- `symptom.body` / `symptom.save` exist on the `A11yID` enum only — **not attached**

## How to get to it (user POV)

Cycle → + Symptom (`cycle.action.symptom`).

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| Sheet | `sheet.symptom` | Present after `cycle.action.symptom`. |
| Close | `sheet.close` | First-use path: tap scores, then close. Sheet gone. |
| Score | `symptom.score.{id}.{1-4}` | First-use: `hot_flash` 3, `sleep` 2, `joints` 1. |
| Body / note | `symptom.body` | On the `A11yID` enum only; the sheet has no note field (`persist` always passes `note: nil`). Do not drive it. |
| Save | `symptom.save` | On the `A11yID` enum only. First-use uses `sheet.close`. Do not drive it. |

After logging, Cycle shows `cycle.chip.score.{id}` via `A11yID.chipScore(_:)`. Hot flash 3 in en: value contains `strong`.

`AppRobot.addSymptom()` is the packaged path.

## Gotchas

- Catalog ids are snake_case (`hot_flash`), not the display name.
- Severity 1–4. Do not write 0 for "untouched".
- Keep the `cycle.chip.score.` literal in this map so check-feature-map still sees `A11yID.chipScore`.
