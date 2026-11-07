# Medication sheet

Create or edit a medication and its schedule. Presented over Cycle.

## Sub-features

- Name, form, default dose, color
- Start (required) and optional end
- Remind toggle
- Optional Dose-from date next to the dose field when default dose or primary schedule actually changed
- Schedule mode: every day / specific days / cyclic
- Save / delete (delete confirms). A new medication is titled New medication (German: Neues Medikament). Edit keeps Edit medication (German: Medikament bearbeiten). Both actions say Save (German: Speichern). Cancel sits on the left of the pinned footer and Save on the right. Edit places Delete between them. The footer stays put while the fields scroll.

## How to get to it (user POV)

Cycle → + Med (`cycle.action.med`) for a new one, or a lane's edit control for an existing one. Do not add a full page.

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| Sheet | `sheet.med` | Present after `cycle.action.med`. Gone after save. |
| Close | `sheet.close` | Shared across sheets. |
| Name | `med.name` | `AppRobot.clearAndType`. |
| Form | `med.form` | The sheet opens on Pill. `testUserFlow` does not open the menu. `pick` still accepts a visible label such as `Cream`. |
| Dose | `med.dose` | e.g. `1 mg`, `200 mg`. |
| Mode | `med.mode` | Picker itself. Options are picked by ID, not English labels. |
| Mode every day | `med.mode.everyday` | The sheet opens on Every day. `testUserFlow` does not open the menu. |
| Mode cyclic | `med.mode.cyclic` | `pick("med.mode", "med.mode.cyclic")` when `addMedication` is called with `cyclic: true`. The user flow does not. |
| Preset | `med.preset` | On the `A11yID` enum but **not attached** in the sheet. Do not drive it. |
| Start | `med.start` | `AppRobot.setDateKey`. Confirm with `date.done`. |
| Dose from (effective date) | `med.since` | Sits next to the dose field, not after the schedule. Present when dose or schedule differs from the stored med (including a new med with a dose). `AppRobot.addMedication` saves by `med.save` and does not wait for this field. Catalog still waits for it. |
| Time chooser done | `time.done` | Same chrome as `date.done`, for take-at times. |
| Remind | `med.remind` | Toggle on the sheet. |
| Save | `med.save` | Pinned footer, right side. Sheet dismisses. A `cycle.lane.{slug}` appears. |
| Delete | `med.delete` | Pinned footer, between Cancel and Save, on edit only. Then `confirm.delete` / `confirm.cancel`. |

`AppRobot.addMedication(name:dose:form:cyclic:start:)` is the packaged path. It leaves the type on Every day. It opens the menu only for a cyclic medication. Form pick still uses the visible label (`Cream`). The user flow does not pick a form. Pill is the default.

## Gotchas

- Schedule modes are exclusive: every day, specific weekdays, or cyclic (apply N / pause M). Saved without menstrual-alignment UI (`cycleRule: none` in the editor).
- Sheet body scrolls. Rows below the fold are not `isHittable`; `AppRobot` taps by coordinate after dismissing the keyboard.
- Name slug for the lane is computed from the **name** (`Estrogen` → `cycle.lane.estrogen`).
- Domain owns schedule expansion (`ios/Sources/PeriMediDomain`). Do not reimplement cycle math in the sheet.
- `med.preset` is defined on the enum only; the sheet does not attach it.
