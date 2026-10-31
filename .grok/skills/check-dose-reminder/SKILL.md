---
name: check-dose-reminder
description: "Check the dose reminder model when a change touches DoseReminderCenter, the widget take, CycleView.toggleLane, or Store.setDoseStatus. Run the model, and use /maintain-formal-verification-skill when a merge skipped this skill."
---

# Check the dose reminder

One planned slot. `Store.setDoseStatus` is the only writer of the dose log. The notification center and the widget file are separate stores. This model checks every interleaving inside its bounds.

## When

Run `python3 ios/scripts/check-dose-reminder.py` before you finish an edit to the covered code. A change to `DoseReminderCenter.markSlotTaken` or `DoseReminderCenter.reschedule` is the trigger.

If the edit changes what a take or a reschedule promises, update `ios/formal/dose-reminder/DoseReminder.tla` in the same change. Move the sync commit only after the model describes the new code. A docs-only edit does not move it.

`python3 ios/scripts/check-dose-reminder-model.py` fails the `ids` job when a covered symbol changes, or a covered file is renamed or deleted, and that same change leaves `DoseReminder.tla`, `DoseReminder.cfg`, and the sync commit below untouched.

When a merge changed the covered code and skipped this skill, use `/maintain-formal-verification-skill`.

## Command

From the repo root:

```bash
python3 ios/scripts/check-dose-reminder.py
```

The command exits 1 when an invariant fails. CI runs the same command with `--warn` and does not fail the workflow. Do not add the command to `control-perimedi verify`.

The checker downloads TLC 1.7.4 on first use and needs `java` on PATH (Java 11 or later).

## What a result means

`PASS` means that invariant holds for every interleaving in the model. `FAIL` on `TakenNotPending` means a taken dose can still be delivered. `FAIL` on `WidgetHidesTaken` means the widget can still list a taken dose. `FAIL` on `WritersAgree` means one time has two dose logs, or those logs do not share one status. Any other `FAIL` is a new bug, or the model no longer describes the code.

Do not weaken an invariant to make the command pass. Do not change product code from this skill unless the user asks. Read the TLC output with the pstack `/statechart` skill. It shows each broken rule as its shortest path. The chart is `docs/statecharts/dose-reminder.md`.

## Covered code

- `DoseReminderCenter.markSlotTaken`, `DoseReminderCenter.markMedicationTaken`, `DoseReminderCenter.refresh`, `DoseReminderCenter.reschedule`, and `DoseReminderCenter.cancelNotifications` in `ios/PeriMedi/App/DoseReminderCenter.swift`
- `DoseWidgetBridge.takeFromWidget` and `DoseWidgetBridge.publish` in `ios/PeriMedi/App/DoseWidgetBridge.swift`
- `CycleView.toggleLane` in `ios/PeriMedi/Features/Cycle/CycleView.swift`
- `Store.setDoseStatus` in `ios/PeriMedi/Persistence/Store.swift`
- `NextPendingDose.resolve` in `ios/Sources/PeriMediDomain/NextPendingDose.swift`
- `MarkTodayMedicationTakenIntent.perform` in `ios/PeriMediDoseWidgetSupport/MarkDoseTakenIntent.swift`

Sync commit: `a124db5`

## Bounds

One slot and one medication. Status is pending or taken. `live` is none or pending, and that one bit is the dose id, a follow-up id, or the snooze id. The queue holds at most two of add and cancel, and the tail does not repeat. The lane keeps the log id and the status it showed, or it is idle. A nil id stays open so another take can insert first. The widget file and the timeline are two booleans.

## Left out

Left out: `ReminderLogic.followUpPlan`. The model does not describe its follow-up schedule.

The model cannot show a follow-up or a snooze pending beside the dose id, and it cannot show snooze leaving the dose id in place. It leaves out the master switch, a denied authorization, and a second `reschedule` that overlaps the first. It leaves out tomorrow's frozen `nextMeds`.

## Findings

`TakenNotPending` holds. A take drops a queued add and clears a live reminder. `CommitPlan` may still read a stale empty pending list. That read cannot install the add once the dose is taken.

`WidgetHidesTaken` fails. `publish` writes today's pending meds, the take's later write fails, and the timeline reload copies the file that still lists the dose. A write that succeeds and has not reloaded yet leaves the same dose on the timeline. Filed as #128.

`WritersAgree` checks at most one row for the slot, and those rows share one status, whatever order the writers run. TLC fails it when the dose button keeps a nil id and a take inserts a row before that button writes. Filed as #132.
