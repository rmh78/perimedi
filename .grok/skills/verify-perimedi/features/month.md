# Month

Calendar overview of the same store Cycle shows.

## Sub-features

- Month grid of days
- Today button (shared ID with Cycle: `cycle.pager.today`)
- Prev / next month chevrons (`month.pager.prev` / `month.pager.next`)
- Day tokens: selected, period, taken, symptom

## How to get to it (user POV)

Bottom bar → Month.

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| Month tab | `tab.month` | Tab exists on launch. |
| A day cell | `month.day.{yyyy-MM-dd}` | Catalog pictures pin today to `2026-03-15`. `testUserFlow` waits for `month.day.` plus the device date and does not read the cell value. |
| Today | `cycle.pager.today` | **Same ID as Cycle (documented choice).** On Month it jumps the month anchor to today and selects today. Do not add a Month-only today ID. |
| Prev month | `month.pager.prev` | First-use pages back to the month that contains today. |
| Next month | `month.pager.next` | First-use pages from March 2026 to April (`month.day.2026-04-01`). |

`testUserFlow` opens Month after the symptom and waits for today's cell. It does not page, tap today, or return through a selected period day.

## Gotchas

- Month is a projection of the store, not a second source of truth. If Cycle says taken and Month does not, the bug is in the month model or the day-value encoding, not a separate database.
- `cycle.pager.today` is shared. Do not assume it is Cycle-only.
- After checking Month, first-use returns via `tab.cycle` and re-asserts lane status so the tab switch did not drop state.
- Selecting a day on Month then opening Cycle keeps that day selected and scrolls it into the visible plot (first-use after the Month pager).
