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
| Banner | `reminder.banner` | `testEnglishAppJourney` waits up to 12s after saving estrogen, and again after untaking that lane. Title “Time for your dose”, medication name, then body with dose and planned time. German title copy is the l10n check. |
| Taken | `reminder.taken` | Primary action on the right. Banner gone; `cycle.lane.{slug}.status` becomes `taken`. The English journey takes estrogen, then progesterone, before Month. |
| Snooze | `reminder.snooze` | Left of Taken. Banner dismisses without taking. The English journey taps it between the untake and the second estrogen take. |
| More master | `more.reminders` | See [more.md](more.md). |
| Per-med remind | `med.remind` | On [medication-sheet.md](medication-sheet.md). |

`JourneyLaunch.pinnedRemindIn(seconds: 2)` fires the next pending slot in-process on `testEnglishAppJourney`. Save estrogen first so a lane exists with `not-taken`, then wait for the banner. Do not launch a second process for the reminder.

## Gotchas

- Springboard banners are unreliable in XCTest. Use `-remindIn`, not a real notification.
- Banner proof is on iPhone 17e only. `testEnglishAppJourney` can save the med and still miss `reminder.banner` within 12s (`-remindIn=2`) on any other phone. Do not treat that miss as coverage.
- Taken on the banner uses the same path as the notification action. System banners use title/subtitle/body (medication name is subtitle, not title). Springboard copy is not XCTest-asserted.
- German Taken is “Genommen” so it matches the body (“Tippe auf Genommen”).
- Master switch off on More means no banner, even if `med.remind` is on.
- Fresh install with master on asks for notification permission. `-uiTesting` skips that prompt so CI is not blocked. After the user allows, dose notifications are rebuilt with an explicit time zone (calendar components without a zone can be dropped on device).
