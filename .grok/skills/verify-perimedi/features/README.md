# PeriMedi feature map

Index of user-facing surfaces. IDs are from `ios/PeriMedi/App/A11yID.swift` unless a file says otherwise. Drive with `AppRobot`.

| Surface | File | How a user gets there |
|---|---|---|
| Cycle (home) | [cycle.md](cycle.md) | Default tab `tab.cycle` |
| Month | [month.md](month.md) | `tab.month` |
| Trends | [trends.md](trends.md) | Bottom tab `tab.trends` (third; not on Cycle) |
| More | [more.md](more.md) | `tab.more` |
| Medication sheet | [medication-sheet.md](medication-sheet.md) | Cycle `cycle.action.med`, or a lane edit |
| Period sheet | [period-sheet.md](period-sheet.md) | Cycle `cycle.action.period` |
| Symptom sheet | [symptom-sheet.md](symptom-sheet.md) | Cycle `cycle.action.symptom` |
| Dose reminders | [reminders.md](reminders.md) | In-app banner, or More toggle |
| Doctor visit PDF | [doctor-visit.md](doctor-visit.md) | More, Doctor visit → Share PDF |
| Backup / sample | [backup.md](backup.md) | More, Backup section |

Canonical ID source: `ios/PeriMedi/App/A11yID.swift`. Tests: `ios/PeriMediUITests/`. Main-screen PNGs: `ios/docs/screens/` (review Files changed; no PR comment galleries).

`python3 ios/scripts/check-ui-coverage.py` reports which of these surfaces UI tests never drive. Advisory today (does not fail CI). `tab.*` does not count as coverage. Backup is blocked until it has IDs.
