# Dose reminders

In-app banner for a pending slot, plus the More master switch.

## Sub-features

- Banner with title, medication name, dose/time body, Taken / Snooze
- Master toggle and sound on More
- Extra reminders Off / 2 / 3 on More (`more.reminderFollowUps`). Default Off. The helper says the wait is 10 minutes. Proof is the English journey on More, not a system banner. Off leaves one planned reminder plus manual Snooze. 2 or 3 plants that many follow-ups. Taken, Snooze, or a slot that is no longer pending stops them. The chain does not continue after Snooze fires and does not pass the chosen count. Denied permission adds no other alert. `-remindIn` does not plant the chain.
- Per-medication remind toggle on the medication sheet

## How to get to it (user POV)

Turn reminders on in More. Enable remind on a medication. When a slot is due, a banner appears over the app. Springboard notifications are **not** the XCTest proof.

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| Banner | `reminder.banner` | `testEnglishAppJourney` waits up to 12s for the banner after saving estrogen, after untaking that lane, and after saving progesterone. It does not read the banner title. The More language step checks the More tab label, not the banner. |
| Taken | `reminder.taken` | Primary action on the right. Banner gone; `cycle.lane.{slug}.status` becomes `taken`. The English journey takes estrogen, then progesterone, before Month. |
| Snooze | `reminder.snooze` | Left of Taken. Banner dismisses without taking. The English journey taps it between the untake and the second estrogen take. |
| More master | `more.reminders` | See [more.md](more.md). |
| Extra reminders | `more.reminderFollowUps` | Segmented Off / 2 / 3 on the Reminders card. See [more.md](more.md). `testEnglishAppJourney` waits for it, selects 2, then Off. It does not open the system permission dialog. |
| Per-med remind | `med.remind` | On [medication-sheet.md](medication-sheet.md). |

`JourneyLaunch.pinnedRemindIn(seconds: 2)` fires the next pending slot in-process on `testEnglishAppJourney`. Save estrogen first so a lane exists with `not-taken`, then wait for the banner. Do not launch a second process for the reminder.

## Gotchas

- Springboard banners are unreliable in XCTest. Use `-remindIn`, not a real notification.
- Banner proof is on iPhone 17e only. `testEnglishAppJourney` can save the med and still miss `reminder.banner` within 12s (`-remindIn=2`) on any other phone. Do not treat that miss as coverage.
- Taken on the banner uses the same path as the notification action. System banners use title/subtitle/body (medication name is subtitle, not title). Springboard copy is not XCTest-asserted.
- German Taken is “Genommen” so it matches the body (“Tippe auf Genommen”).
- Master switch off on More means no banner, even if `med.remind` is on.
- Fresh install with master on asks for notification permission. `-uiTesting` skips that prompt so CI is not blocked. After the user allows, dose notifications are rebuilt with an explicit time zone (calendar components without a zone can be dropped on device).
