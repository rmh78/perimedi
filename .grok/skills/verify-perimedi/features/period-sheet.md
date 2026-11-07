# Period sheet

Log bleeds and cycle length. Day 1 of a cycle is the first period day. Presented over Cycle.

## Sub-features

- Track on/off and average cycle / period length. Done dismisses the settings sheet and keeps those values. There is no Cancel on that sheet.
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
| Cycle length | `period.cycleDays` | Menu of day counts. `testImmediateActionsKeepWhatTheyShow` changes 28 to 29, taps Done, reopens the sheet, and reads 29. |
| Period length | `period.periodDays` | Menu of day counts. That same test leaves it at 5. |
| Add | `period.add` | Opens the card. May sit below the fold. The robot swipes up if it is missing. |
| Start | `period.start` | In the card. `setDateKey`. The filled English label for 7 March 2026 is Mar 7, 2026. The accessibility value stays 2026-03-07. |
| End | `period.end` | In the card. Empty English reads Optional. Empty German reads TT.MM.JJJJ. The user flow leaves it empty. |
| Save | `period.save` | Right side of the card. Label is Save. The card closes and the history row stays on the sheet. |
| Cancel | `confirm.cancel` | Left side of the new-period card. The user flow does not tap it. |
| History | `period.history.{id}` | One row per saved period. The underlined date range shares that line with the length and flow. A closed period uses the same date-range format as a cycle in the doctor’s visit dialog. Opens the same card filled in. Match the row by that range label. The user flow does not open a history row. |
| Delete | `period.delete` | On the edit card’s button row, between Cancel and Save. Those labels share one type size. If one must shrink, they all shrink together. The row grows with the text size. A label never drops below half size. When one would, every label on the row wraps to two lines at that shared half size. The break is a space between words, or a hyphen at a real hyphenation point. VoiceOver reads the whole word. The card then asks `Delete {{name}}?` using that range. That question uses the same row, Cancel on the left and Delete on the right (`confirm.delete`). The user flow does not delete a period. |
| Date chooser done | `date.done` | Used by `setDateKey`. The chooser shows Done. Clear is there when the date may be empty. There is no Cancel. `testImmediateActionsKeepWhatTheyShow` sets `period.end`, taps Clear, and the value no longer contains that date. |

`testUserFlow` adds one period and saves the new card as it opens. Start is the selected day. The end stays empty. The flow stays medium. It waits for `period.add`, then closes the sheet. It does not open the date choosers and does not assert strip tokens.

## Gotchas

- The period card is its own layer on the settings sheet. A tap on the dim, including the page above the sheet, drops the card and leaves settings. It does not save. Cancel on the editor does the same. On the delete question, Cancel returns to the editor. A dim tap on that question drops the card and does not delete. `testNestedDimKeepsParent` opens that question, taps Cancel, then taps the page above the sheet. The history row is still there and the settings sheet is still open. A second tap there, with no card up, closes the settings sheet.
- No menstrual phase labels.
- Period UI on Cycle is label + background only.
- `period.add` is easy to miss without a swipe. Don't treat "missing" as "not implemented" until you scroll.
- The next-period line spells a full month, 4. April 2026 in German or Mar 7, 2026 in English, with the day and the month kept together. The line scales down when that day-month run is wider than the line.
- Start and end share one row at the default text size. They stack when a column's minimum width is wider than half the row. The user flow does not measure midY.
