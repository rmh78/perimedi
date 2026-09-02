# Medication sheet

Create or edit a medication and its schedule. Presented over Cycle.

## Sub-features

- Name, form, default dose, color
- Start (required) and optional end
- Remind toggle
- Optional Since date when default dose or primary schedule actually changed
- Schedule mode: every day / specific days / cyclic
- Save / delete (delete confirms)

## How to get to it (user POV)

Cycle → + Med (`cycle.action.med`) for a new one, or a lane's edit control for an existing one. Do not add a full page.

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| Sheet | `sheet.med` | Present after `cycle.action.med`. Gone after save. |
| Close | `sheet.close` | Shared across sheets. |
| Name | `med.name` | `AppRobot.clearAndType`. |
| Form | `med.form` | `AppRobot.pick` — first-use uses visible `Cream`. |
| Dose | `med.dose` | e.g. `1 mg`, `200 mg`. |
| Mode | `med.mode` | Picker itself. Options are picked by ID, not English labels. |
| Mode every day | `med.mode.everyday` | `pick("med.mode", "med.mode.everyday")` via `AppRobot.addMedication` (cyclic: false). |
| Mode cyclic | `med.mode.cyclic` | `pick("med.mode", "med.mode.cyclic")` via first-use cyclic progesterone. |
| Preset | `med.preset` | On the `A11yID` enum but **not attached** in the sheet. Do not drive it. |
| Start | `med.start` | `AppRobot.setDateKey`. Confirm with `date.done`. |
| Since (effective date) | `med.since` | Present when dose or schedule differs from the stored med (including a new med with a dose). `AppRobot.addMedication` waits for it after typing dose. |
| Time chooser done | `time.done` | Same chrome as `date.done`, for take-at times. |
| Remind | `med.remind` | Toggle on the sheet. |
| Save | `med.save` | Sheet dismisses. A `cycle.lane.{slug}` appears. |
| Delete | `med.delete` | Then `confirm.delete` / `confirm.cancel`. |

`AppRobot.addMedication(name:dose:form:cyclic:start:)` is the packaged path. Mode is `med.mode.everyday` or `med.mode.cyclic`. Form pick still uses the visible label (`Cream`).

## Gotchas

- Schedule modes are exclusive: every day, specific weekdays, or cyclic (apply N / pause M). Saved without menstrual-alignment UI (`cycleRule: none` in the editor).
- Sheet body scrolls. Rows below the fold are not `isHittable`; `AppRobot` taps by coordinate after dismissing the keyboard.
- Name slug for the lane is computed from the **name** (`Estrogen` → `cycle.lane.estrogen`).
- Domain owns schedule expansion (`ios/Sources/PeriMediDomain`). Do not reimplement cycle math in the sheet.
- `med.preset` is defined on the enum only; the sheet does not attach it.
