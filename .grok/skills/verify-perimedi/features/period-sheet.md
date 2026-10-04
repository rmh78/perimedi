# Period sheet

Log bleeds and cycle length. Day 1 of a cycle is the first period day. Presented over Cycle.

## Sub-features

- Track on/off and average cycle / period length
- Add a period (start, optional end, flow) in a card titled New period
- Underlined history range `period.history.{id}` opens the same card titled Edit period
- Delete `period.delete` replaces that card with a question that names the date range. Confirm with `confirm.delete`

## How to get to it (user POV)

Cycle → cycle settings (`cycle.action.period`).

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| Sheet | `sheet.period` | Present after `cycle.action.period`. |
| Close | `sheet.close` | `AppRobot.closeSheet(id: "sheet.period")`. |
| Add | `period.add` | Opens the card. May sit below the fold. The robot swipes up if it is missing. |
| Start | `period.start` | In the card. `setDateKey`. First-use: `2026-03-07`. |
| End | `period.end` | In the card. First-use: `2026-03-11`. |
| Save | `period.save` | Right side of the card. Label is Save. Then close the sheet. |
| History | `period.history.{id}` | Underlined date range. Opens the same card filled in. Proof: testEditAndDeletePeriod. |
| Delete | `period.delete` | In the edit card. The card then asks `Delete {{name}}?` using that range. Confirm with `confirm.delete`. Proof: testEditAndDeletePeriod. |
| Date chooser done | `date.done` | Used by `setDateKey`. |

After save, Cycle strip days `cycle.strip.day.2026-03-07` and `…-11` values contain `period`. Empty-meds chip drops `need-period` and becomes `need-med`. Intro is gone.

`AppRobot.addPeriod()` is the packaged path.

## Gotchas

- No menstrual phase labels.
- Period UI on Cycle is label + background only.
- `period.add` is easy to miss without a swipe. Don't treat "missing" as "not implemented" until you scroll.
