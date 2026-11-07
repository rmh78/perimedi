# Dose reminders

In-app banner for a pending slot, plus the More master switch.

## Sub-features

- Banner with title, medication name, dose/time body, Close / Snooze / Taken. Close dismisses the banner. It does not record the dose, snooze, or turn reminders off. Snooze is not destructive.
- Master toggle and sound on More
- Extra reminders Off / 2× / 3× on More (`more.reminderFollowUps`). Default Off. Title is Remind me again. The helper says up to 2 or 3 more reminders, 10 minutes apart, until the dose is marked taken. The row stays visible. While the master switch is off it is dimmed and disabled. The user flow does not drive these pills. A system banner is not the proof. Off leaves one planned reminder plus manual Snooze. 2 or 3 plants that many follow-ups. Taken, Snooze, or a slot that is no longer pending stops them. The chain does not continue after Snooze fires and does not pass the chosen count. Denied permission adds no other alert. `-remindIn` does not plant the chain.
- Per-medication remind toggle on the medication sheet

## How to get to it (user POV)

Turn reminders on in More. Enable remind on a medication. When a slot is due, a banner appears over the app. Springboard notifications are **not** the XCTest proof.

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| Banner | `reminder.banner` | The user flow does not open the banner. `-uiTesting` without `-remindIn` clears pending notifications. |
| Taken | `reminder.taken` | Primary action on the right. The user flow does not wait for it. The Cycle lane tap is the in-app Taken. |
| Close | the word Close (German: Schließen) | Left of the banner row. `testImmediateActionsKeepWhatTheyShow` taps it. The banner goes away, the lane stays Not taken, and `med.remind` stays on. |
| Snooze | `reminder.snooze` | Middle of the banner row, between Close and Taken. The user flow does not tap it. |
| More master | `more.reminders` | See [more.md](more.md). Catalog waits for it. The user flow does not. |
| Extra reminders | `more.reminderFollowUps` | Pills Off / 2× / 3× on the Reminders card. See [more.md](more.md). The user flow does not tap them. |
| Per-med remind | `med.remind` | On [medication-sheet.md](medication-sheet.md). |

`JourneyLaunch.userFlow` does not pass `-remindIn`. The flow marks the Cycle lane taken and puts it back before the medium widget Take. Catalog waits for `more.reminders` on the sample More screen. Do not launch a second process for a reminder.

## Gotchas

- Springboard banners are unreliable in XCTest. Use `-remindIn`, not a real notification.
- Take proof is the medium widget on iPhone 17e. `testUserFlow` does not wait for `reminder.taken`.
- Taken on the banner uses the same path as the notification action. System banners use title/subtitle/body (medication name is subtitle, not title). Springboard copy is not XCTest-asserted.
- Marking a dose taken shows it as taken before removal of that dose's pending and delivered system notification finishes. The system notification may remain until that background removal returns. Take does not wait. Put-back shows not taken without waiting and does not remove a notification that was already delivered.
- German Taken is “Genommen” so it matches the body (“Tippe auf Genommen”).
- Master switch off on More means no banner, even if `med.remind` is on.
- Fresh install with master on asks for notification permission. `-uiTesting` skips that prompt so CI is not blocked. After the user allows, dose notifications are rebuilt with an explicit time zone (calendar components without a zone can be dropped on device).
