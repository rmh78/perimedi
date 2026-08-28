# Month

Calendar overview of the same store Cycle shows.

## Sub-features

- Month grid of days
- Today button (shared ID with Cycle)
- Prev / next month chevrons (labels only, no IDs)
- Day tokens: selected, period, taken, symptom

## How to get to it (user POV)

Bottom bar → Month.

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| Month tab | `tab.month` | Tab exists on launch. |
| A day cell | `month.day.{yyyy-MM-dd}` | First-use today (`2026-03-15`) value contains `selected`. Period start contains `period`. A taken+symptom day contains `taken` and `symptom`. |
| Today | `cycle.pager.today` | **Same ID as Cycle.** On Month it jumps the month anchor to today and selects today. |

Prev/next month buttons use `accessibilityLabel` from `month.prevMonth` / `month.nextMonth` (localized). They have **no** `A11yID`. Prefer `month.day.{dateKey}` plus Today, or extend `A11yID` if you need to page months in tests.

## Gotchas

- Month is a projection of the store, not a second source of truth. If Cycle says taken and Month does not, the bug is in the month model or the day-value encoding, not a separate database.
- `cycle.pager.today` is shared. Do not assume it is Cycle-only.
- After checking Month, first-use returns via `tab.cycle` and re-asserts lane status so the tab switch did not drop state.
