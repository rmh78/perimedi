# Home Screen today's-meds widget

Home Screen widget for today's untaken medications, with Taken at Cycle lane grain for today. SpringBoard is not an XCTest surface.

## Sub-features

- Occupied card: today's pending medications (overdue included, reminder-off included), stacked with `+N` when more than one remains
- Empty card when nothing is pending today (another day's doses do not appear)
- Taken marks every remaining pending slot for that medication on today
- Chrome follows the in-app language (en/de); medication name and dose label stay user text

## How to get to it (user POV)

Add the PeriMedi widget from the Home Screen widget gallery. The app must have launched at least once so it can publish the snapshot. Taken does not open Cycle.

## Driving it with A11yID / AppRobot

Blocked. SpringBoard widgets have no `A11yID` and are not driven by `AppRobot`. Do not add widget identifiers.

Proof is domain plus the existing reminder Taken journey:

- `TodayPendingMedsTests` for today's list (today not tomorrow, group two times, taken drops, reminder-off, pause, empty)
- `NextPendingDoseTests` for reminder `resolve` (pending, already taken, missing)
- `testDoseReminderTaken` for reminder Taken through `Store.setDoseStatus` and Cycle `taken`

## Gotchas

- The widget reads App Group JSON only. It does not call `TodayPendingMeds.list` and does not open SwiftData.
- Taken is `medicationId` only on an App Intent that must run in the app process. If it ran in the extension it fails closed.
- Today only: `visible(at:)` shows `meds` when the device date matches `date`, or `nextMeds` after midnight until the app republishes. It never shows a later day as the visible list.
- Unsigned Simulator (`CODE_SIGNING_ALLOWED=NO`) never stamps `group.app.perimedi.ios`. `containerURL` is nil, `publish` cannot write `next-dose.json`, and the widget shows the missing-file empty chrome (`Heute nichts zu nehmen` / `Nothing to take today`) even when Cycle has pending slots. Local install must be signed (no `CODE_SIGNING_ALLOWED=NO`). `control-perimedi verify` stays unsigned on purpose.
- No distinctive IDs on purpose. Coverage would fail `check-ui-coverage.py --fail-uncovered` if SpringBoard IDs were added and never tapped.
- The widget is not a fifth tab. Bottom nav stays Cycle, Month, Trends, More.
