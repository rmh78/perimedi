# PeriMedi feature map

Index of user-facing surfaces. IDs are from `ios/PeriMedi/App/A11yID.swift` unless a file says otherwise. Drive with `AppRobot`.

| Surface | File | How a user gets there |
|---|---|---|
| Cycle (home) | [cycle.md](cycle.md) | Default tab `tab.cycle` |
| Month | [month.md](month.md) | `tab.month` |
| More | [more.md](more.md) | `tab.more` |
| Medication sheet | [medication-sheet.md](medication-sheet.md) | Cycle `cycle.action.med`, or a lane edit |
| Period sheet | [period-sheet.md](period-sheet.md) | Cycle `cycle.action.period` |
| Symptom sheet | [symptom-sheet.md](symptom-sheet.md) | Cycle `cycle.action.symptom` |
| Dose reminders | [reminders.md](reminders.md) | In-app banner, or More toggle |
| Backup / sample | [backup.md](backup.md) | More, Backup section (no IDs yet) |

Canonical ID source: `ios/PeriMedi/App/A11yID.swift`. Tests: `ios/PeriMediUITests/`.
