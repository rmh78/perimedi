# More

Settings: language, reminders, doctor-visit PDF, backup, privacy policy link.

## Sub-features

- Language (en / de) — `more.lang.en` / `more.lang.de`
- Master reminders toggle
- Reminder sound picker + preview (`more.reminderSoundPreview`)
- Extra reminders Off / 2× / 3× (`more.reminderFollowUps`). Three pills. Default Off. Title is Remind me again (German: Nochmal erinnern). Helper: up to 2 or 3 more reminders, 10 minutes apart, until the dose is marked taken. The row stays visible. While the master switch is off, the row is dimmed and disabled.
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
| English language pill | `more.lang.en` | The user flow does not wait for it. Catalog taps it after the German More picture. |
| German language pill | `more.lang.de` | The user flow does not tap it. Catalog writes `more-sample-de.png`. |
| Reminders master switch | `more.reminders` | Toggle. On by default (`DoseReminderCenter.masterKey`). Catalog waits for it before the More picture. The user flow does not wait for it. |
| Reminder sound menu | `more.reminderSound` | Picker. The user flow does not wait for it. |
| Reminder sound preview | `more.reminderSoundPreview` | Speaker button. The user flow does not tap it. |
| Extra reminders | `more.reminderFollowUps` | Pill row (Off, 2×, 3×) on a container. Stays on screen when the master switch is off, dimmed and disabled so it does not accept a change. The user flow does not tap these pills. |
| Open Settings (denied) | `more.remindersSettings` | Only visible when `notifyDenied`. Do not tap it. It opens iOS Settings. |
| Privacy Policy | `more.privacyPolicy` | Opens the published privacy page in Safari. The user flow does not wait for it. |
| Share visit PDF | `more.sharePdf` | See [doctor-visit.md](doctor-visit.md). |
| Backup rows | `more.sample` / `more.export` / `more.import` / `more.clear` | See [backup.md](backup.md). |

`testUserFlow` opens More after Trends, scrolls to `more.sharePdf`, continues to the preview, waits for `visit.pdf.share`, taps `visit.pdf.back`, sees `visit.range`, then closes so `visit.range` is gone. It does not switch language, wait for `more.lang.en`, tap reminder controls, tap Share, or wait for `more.sample`. German nav strings stay `check-l10n-layout.py`. Catalog waits for `more.reminders` before the More picture and for `more.sample` after its preview closes.

Language pills call `LocaleController`. Preference is `AppStorage` `perimedi.locale`. Default German if device preferred languages include German. The user flow forces English with `-en` and does not switch. The whole More tab box is tappable, not only the ellipsis or the word More.

Disclaimer copy is a personal companion, not a demo.

If notification permission is denied and the master switch is on, More shows `more.remindersDenied` copy and a settings button (`more.remindersSettings`). Fresh install with the master switch on (default) asks for permission once; UI tests launch `-uiTesting` and do not show the system dialog.

## Gotchas

- Backup row IDs and journey rules live in [backup.md](backup.md).
- Language control lives here, not in Cycle. User-entered text is never translated.
- Reminder delivery proof is the in-app banner on Cycle (`reminders.md`), not this toggle alone.
- `med.remind.turnOn` stays on the medication sheet and turns `more.reminders` on. Do not tap `med.remind.iosSettings`.
