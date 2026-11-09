# Medication sheet

Create or edit a medication and its schedule. Presented over Cycle.

## Sub-features

- Name, form, default dose, color
- Start (required) and optional end
- Remind toggle. The lines under it explain the two outside gates. They are below the fold.
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
| Time chooser done | `time.done` | Done dismisses the chooser. `testImmediateActionsKeepWhatTheyShow` moves the default 20:00 to 21:00, taps Done, and reads 21:00 on the still-open new-medication sheet. It reopens the chooser and reads the same hour. The sheet is then closed without Save. The test does not open it again after that close. |
| Remind | `med.remind` | Toggle after take times and before Type. Label is Remind me (German: Erinnere mich). A new medication starts on. |
| App reminders off | `med.remind.appOff` | Muted line directly under `med.remind`, not in the toggle label and not in the footer. Below the fold, so `scrollTo` this id. |
| Turn on | `med.remind.turnOn` | Action under that line. Shows More and leaves `more.reminders` off. |
| iOS notifications denied | `med.remind.iosDenied` | Muted line under `med.remind`, after the app line when both show. Below the fold. No XCUITest drives denial. |
| Open Settings | `med.remind.iosSettings` | Action under the iOS line. Leaves the app. No XCUITest taps it. |
| Save | `med.save` | Pinned footer, right side. Sheet dismisses. A `cycle.lane.{slug}` appears. |
| Delete | `med.delete` | Pinned footer, between Cancel and Save, on edit only. Then `confirm.delete` / `confirm.cancel`. |

`AppRobot.addMedication(name:dose:form:cyclic:start:)` is the packaged path. It leaves the type on Every day. It opens the menu only for a cyclic medication. Form pick still uses the visible label (`Cream`). The user flow does not pick a form. Pill is the default.

## Gotchas

- Schedule modes are exclusive: every day, specific weekdays, or cyclic (apply N / pause M). Saved without menstrual-alignment UI (`cycleRule: none` in the editor).
- A closed apply-days or pause-days menu shows ink, not system blue.
- Each color swatch keeps its color. The chosen swatch has a dark ring. Every other swatch has a visible blush edge.
- A chosen weekday chip is reported as selected. The label stays the weekday name.
- Sheet body scrolls. Rows below the fold are not `isHittable`; `AppRobot` taps by coordinate after dismissing the keyboard.
- Name slug for the lane is computed from the **name** (`Estrogen` → `cycle.lane.estrogen`).
- Domain owns schedule expansion (`ios/Sources/PeriMediDomain`). Do not reimplement cycle math in the sheet.
- `med.preset` is defined on the enum only; the sheet does not attach it.
- `testAppRemindersOffShowsTheLineAndOpensMore` in `MedicationReminderHonestyTests` turns `more.reminders` off, opens add medication, scrolls to `med.remind.appOff`, reads that line and `med.remind.turnOn`, and checks that `med.remind.iosDenied` is absent. Turn on shows More and leaves `more.reminders` off. Do not tap `med.remind.iosSettings`.
