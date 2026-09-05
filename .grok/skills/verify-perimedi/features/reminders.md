# Dose reminders

In-app banner for a pending slot, plus the More master switch.

## Sub-features

- Banner with title, medication name, dose/time body, Taken / Snooze
- Master toggle and sound on More
- Per-medication remind toggle on the medication sheet

## How to get to it (user POV)

Turn reminders on in More. Enable remind on a medication. When a slot is due, a banner appears over the app. Springboard notifications are **not** the XCTest proof.

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| Banner | `reminder.banner` | `testDoseReminderTaken` waits up to 12s. Title “Time for your dose” (DE: “Zeit für deine Dosis”), medication name, then body with dose and planned time. |
| Taken | `reminder.taken` | First action. Banner gone; `cycle.lane.{slug}.status` becomes `taken`. Label “Taken” / “Genommen”. |
| Snooze | `reminder.snooze` | Banner dismisses without taking. Label “Snooze 10 min” / “10 Min. später”. |
| More master | `more.reminders` | See [more.md](more.md). |
| Per-med remind | `med.remind` | On [medication-sheet.md](medication-sheet.md). |

Launch extra: `-remindIn=4` fires the next pending slot in-process (see `FirstUseJourneyTests.testDoseReminderTaken`). Add a med first so a lane exists with `not-taken`, then wait for the banner.

## Gotchas

- Springboard banners are unreliable in XCTest. Use `-remindIn`, not a real notification.
- Taken on the banner uses the same path as the notification action. System banners use title/subtitle/body (medication name is subtitle, not title). Springboard copy is not XCTest-asserted.
- German Taken is “Genommen” so it matches the body (“Tippe auf Genommen”).
- Master switch off on More means no banner, even if `med.remind` is on.
- Fresh install with master on asks for notification permission. `-uiTesting` skips that prompt so CI is not blocked. After the user allows, dose notifications are rebuilt with an explicit time zone (calendar components without a zone can be dropped on device).
