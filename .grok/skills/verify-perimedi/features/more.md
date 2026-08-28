# More

Settings: language, reminders, backup.

## Sub-features

- Language (en / de) — no IDs
- Master reminders toggle
- Reminder sound picker + preview
- Backup: sample, export, import, clear — no IDs (see [backup.md](backup.md))

## How to get to it (user POV)

Bottom bar → More.

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| More tab | `tab.more` | Exists on launch. |
| Reminders master switch | `more.reminders` | Toggle. On by default (`DoseReminderCenter.masterKey`). |
| Reminder sound menu | `more.reminderSound` | Picker. Preview button is label-only (`more.reminderSoundPreview`), no ID. |

Language pills call `LocaleController` and have **no** accessibility identifiers. Preference is `AppStorage` `perimedi.locale`. Default German if device preferred languages include German. Tests force English with `-en`.

If notification permission is denied, More shows `more.remindersDenied` copy and a settings button (no ID).

## Gotchas

- Backup rows have no IDs. Do not invent `more.sample` etc. Add IDs in `A11yID` if you need to drive them.
- Language control lives here, not in Cycle. User-entered text is never translated.
- Reminder delivery proof is the in-app banner on Cycle (`reminders.md`), not this toggle alone.
