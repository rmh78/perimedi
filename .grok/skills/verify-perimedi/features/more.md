# More

Settings: language, reminders, doctor-visit PDF, backup, privacy policy link.

## Sub-features

- Language (en / de) — `more.lang.en` / `more.lang.de`
- Master reminders toggle
- Reminder sound picker + preview (`more.reminderSoundPreview`)
- Doctor visit PDF — View PDF opens a cycle picker, then an in-app preview (see [doctor-visit.md](doctor-visit.md))
- Backup: sample, export, import, clear (see [backup.md](backup.md))
- Denied-notifications settings row (`more.remindersSettings`)
- Privacy Policy link (`more.privacyPolicy`) → https://rmh78.github.io/perimedi/app-store/privacy

## How to get to it (user POV)

Bottom bar → More.

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| More tab | `tab.more` | Exists on launch. |
| English language pill | `more.lang.en` | `testEnglishAppJourney` taps it after German. `tab.more` reads `More` again. |
| German language pill | `more.lang.de` | Same journey taps it and `tab.more` reads `Mehr`, then switches back. The rest of the German catalog stays the l10n table check. |
| Reminders master switch | `more.reminders` | Toggle. On by default (`DoseReminderCenter.masterKey`). `testEnglishAppJourney` waits for it and taps it after both doses are taken. |
| Reminder sound menu | `more.reminderSound` | Picker. `testEnglishAppJourney` waits for it after toggling reminders. |
| Reminder sound preview | `more.reminderSoundPreview` | Speaker button. Journey taps it. |
| Open Settings (denied) | `more.remindersSettings` | Only visible when `notifyDenied`. Journey includes the ID string so coverage sees it; does not tap (opens iOS Settings). |
| Privacy Policy | `more.privacyPolicy` | Opens the published privacy page in Safari. `testEnglishAppJourney` waits for it; does not tap (leaves the app). |
| Share visit PDF | `more.sharePdf` | See [doctor-visit.md](doctor-visit.md). |
| Backup rows | `more.sample` / `more.export` / `more.import` / `more.clear` | See [backup.md](backup.md). |

`RequiredJourneyTests.testEnglishAppJourney` is the More path, after both doses are taken: `tab.more`, tap `more.lang.de` until `tab.more` reads Mehr, tap `more.lang.en` until it reads More, wait/tap `more.reminders`, wait for `more.reminderSound`, tap `more.reminderSoundPreview`, wait for `more.sharePdf`, tap it through range Continue to the preview, wait `visit.pdf.share`, close, wait for `more.privacyPolicy` and backup row IDs, tap `more.sample` then `confirm.cancel`. Do not tap export, import, clear, the privacy link, or the preview Share button. The other German nav strings stay `check-l10n-layout.py`.

Language pills call `LocaleController`. Preference is `AppStorage` `perimedi.locale`. Default German if device preferred languages include German. The required journey forces English with `-en` and does not switch. The whole More tab box is tappable, not only the ellipsis or the word More.

Disclaimer copy is a personal companion, not a demo.

If notification permission is denied, More shows `more.remindersDenied` copy and a settings button (`more.remindersSettings`). Fresh install with the master switch on (default) asks for permission once; UI tests launch `-uiTesting` and do not show the system dialog.

## Gotchas

- Backup row IDs and journey rules live in [backup.md](backup.md).
- Language control lives here, not in Cycle. User-entered text is never translated.
- Reminder delivery proof is the in-app banner on Cycle (`reminders.md`), not this toggle alone.
