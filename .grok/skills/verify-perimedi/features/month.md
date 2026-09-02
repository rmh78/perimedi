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
| A day cell | `month.day.{yyyy-MM-dd}` | First-use today (`2026-03-15`) value contains `selected`. Period start contains `period`. A taken+symptom day contains `taken` and `symptom`. |
| Today | `cycle.pager.today` | **Same ID as Cycle (documented choice).** On Month it jumps the month anchor to today and selects today. Do not add a Month-only today ID. |
| Prev month | `month.pager.prev` | `testMonthPager` pages back to the month that contains today. |
| Next month | `month.pager.next` | `testMonthPager` pages from March 2026 to April (`month.day.2026-04-01`). |

`testMonthPager` launches, opens Month, asserts today is selected, taps `month.pager.next`, waits for `month.day.2026-04-01`, taps `month.pager.prev`, asserts today selected again, then taps the shared `cycle.pager.today` and re-asserts.

## Gotchas

- Month is a projection of the store, not a second source of truth. If Cycle says taken and Month does not, the bug is in the month model or the day-value encoding, not a separate database.
- `cycle.pager.today` is shared. Do not assume it is Cycle-only.
- After checking Month, first-use returns via `tab.cycle` and re-asserts lane status so the tab switch did not drop state.
