# Period sheet

Log bleeds and cycle length. Day 1 of a cycle is the first period day. Presented over Cycle.

## Sub-features

- Track on/off and average cycle / period length
- Add a period (start, optional end, flow)
- History list with delete confirm

## How to get to it (user POV)

Cycle → cycle settings (`cycle.action.period`).

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| Sheet | `sheet.period` | Present after `cycle.action.period`. |
| Close | `sheet.close` | `AppRobot.closeSheet(id: "sheet.period")`. |
| Add | `period.add` | May sit below the fold — robot swipes up if missing. |
| Start | `period.start` | `setDateKey`. First-use: `2026-03-07`. |
| End | `period.end` | First-use: `2026-03-11`. |
| Save | `period.save` | Then close the sheet. |
| Date chooser done | `date.done` | Used by `setDateKey`. |

After save, Cycle strip days `cycle.strip.day.2026-03-07` and `…-11` values contain `period`. Empty-meds chip drops `need-period` and becomes `need-med`. Intro is gone.

`AppRobot.addPeriod()` is the packaged path.

## Gotchas

- No menstrual phase labels.
- Period UI on Cycle is label + background only.
- `period.add` is easy to miss without a swipe. Don't treat "missing" as "not implemented" until you scroll.
