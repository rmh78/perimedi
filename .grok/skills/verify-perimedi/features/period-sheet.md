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
| Start | `period.start` | In the card. `setDateKey`. The filled English label for 7 March 2026 is Mar 7, 2026. The accessibility value stays 2026-03-07. |
| End | `period.end` | In the card. Empty English reads Optional. Empty German reads TT.MM.JJJJ. First-use save uses `2026-03-11`. |
| Save | `period.save` | Right side of the card. Label is Save. Then close the sheet. |
| Cancel | `confirm.cancel` | Left side of the new-period card. Proof: `testEnglishAppJourney` opens the card, sees an empty `period.end`, taps Cancel, and the end field is gone. |
| History | `period.history.{id}` | One row. The underlined date range shares that line with the length and flow. A closed period uses the same date-range format as a cycle in the doctor’s visit dialog. Opens the same card filled in. Proof: `testEnglishAppJourney` reads `Mar 7, 2026 – Mar 12, 2026`. |
| Delete | `period.delete` | On the edit card’s button row, between Cancel and Save. Those labels share one type size. If one must shrink, they all shrink together. The row grows with the text size. A label never drops below half size. When one would, every label on the row wraps to two lines at that shared half size. The break is a space between words, or a hyphen at a real hyphenation point. VoiceOver reads the whole word. The card then asks `Delete {{name}}?` using that range. Confirm with `confirm.delete`. Proof: `testEnglishAppJourney` reads `Delete Mar 7, 2026 – Mar 12, 2026?`, then the intro returns and the period is logged again. |
| Date chooser done | `date.done` | Used by `setDateKey`. |

After save, Cycle strip days `cycle.strip.day.2026-03-07` and `…-11` values contain `period`. Empty-meds chip drops `need-period` and becomes `need-med`. Intro is gone.

`AppRobot.addPeriod()` is the packaged path.

## Gotchas

- No menstrual phase labels.
- Period UI on Cycle is label + background only.
- `period.add` is easy to miss without a swipe. Don't treat "missing" as "not implemented" until you scroll.
- Start and end share one row at the default text size. `testEnglishAppJourney` checks that `period.start` and `period.end` share a midY within 2 points. They stack when a column's minimum width is wider than half the row. `testPeriodCardAtLargestText` opens the card at the largest accessibility size in English and in German, fills both dates, and checks that the end field starts at or below the start field, the full end hint is on screen and taller than 40 points, and neither date leaves the window.
