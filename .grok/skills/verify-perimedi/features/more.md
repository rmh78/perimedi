# More

Settings: language, reminders, backup, privacy policy link.

## Sub-features

- Language (en / de) — `more.lang.en` / `more.lang.de`
- Master reminders toggle
- Reminder sound picker + preview (`more.reminderSoundPreview`)
- Backup: sample, export, import, clear (see [backup.md](backup.md))
- Denied-notifications settings row (`more.remindersSettings`)
- Privacy Policy link (`more.privacyPolicy`) → https://rmh78.github.io/perimedi/app-store/privacy

## How to get to it (user POV)

Bottom bar → More.

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| More tab | `tab.more` | Exists on launch. |
| English language pill | `more.lang.en` | `FirstUseJourneyTests.testMoreRemindersControls` waits and taps it (tests launch `-en`; do not tap `more.lang.de`). |
| German language pill | `more.lang.de` | Waited for in the same journey. Do not tap — that would switch language. |
| Reminders master switch | `more.reminders` | Toggle. On by default (`DoseReminderCenter.masterKey`). `testMoreRemindersControls` waits for it and taps it. |
| Reminder sound menu | `more.reminderSound` | Picker. `testMoreRemindersControls` waits for it after toggling reminders. |
| Reminder sound preview | `more.reminderSoundPreview` | Speaker button. Journey taps it. |
| Open Settings (denied) | `more.remindersSettings` | Only visible when `notifyDenied`. Journey includes the ID string so coverage sees it; does not tap (opens iOS Settings). |
| Privacy Policy | `more.privacyPolicy` | Opens the published privacy page in Safari. `testMoreRemindersControls` waits for it; does not tap (leaves the app). |
| Backup rows | `more.sample` / `more.export` / `more.import` / `more.clear` | See [backup.md](backup.md). |

`FirstUseJourneyTests.testMoreRemindersControls` is the More path: launch, `tab.more`, wait for language pills and tap `more.lang.en`, wait/tap `more.reminders`, wait for `more.reminderSound`, tap `more.reminderSoundPreview`, wait for `more.privacyPolicy`, wait for backup row IDs, tap `more.sample` then `confirm.cancel`. Do not tap export, import, clear, German, or the privacy link.

Language pills call `LocaleController`. Preference is `AppStorage` `perimedi.locale`. Default German if device preferred languages include German. Tests force English with `-en`.

If notification permission is denied, More shows `more.remindersDenied` copy and a settings button (`more.remindersSettings`). Fresh install with the master switch on (default) asks for permission once; UI tests launch `-uiTesting` and do not show the system dialog.

## Gotchas

- Backup row IDs and journey rules live in [backup.md](backup.md).
- Language control lives here, not in Cycle. User-entered text is never translated.
- Reminder delivery proof is the in-app banner on Cycle (`reminders.md`), not this toggle alone.
