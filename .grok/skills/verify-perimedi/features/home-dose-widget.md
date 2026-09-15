# Home Screen next-dose widget

Home Screen widget for the next pending planned dose, with Taken. SpringBoard is not an XCTest surface.

## Sub-features

- Occupied card: next pending slot (overdue included, reminder-off included)
- Empty card when nothing is pending in the 14-day horizon
- Taken on that slot identity only
- Chrome follows the in-app language (en/de); medication name and dose label stay user text

## How to get to it (user POV)

Add the PeriMedi widget from the Home Screen widget gallery. The app must have launched at least once so it can publish the snapshot. Taken does not open Cycle.

## Driving it with A11yID / AppRobot

Blocked. SpringBoard widgets have no `A11yID` and are not driven by `AppRobot`. Do not add widget identifiers.

Proof is domain plus the existing reminder Taken journey:

- `NextPendingDoseTests` for select and resolve (overdue, taken, pause, reminder-off, sort)
- `testDoseReminderTaken` for Taken through `Store.setDoseStatus` and Cycle `taken`

## Gotchas

- The widget reads App Group JSON only. It does not call `NextPendingDose.select` and does not open SwiftData.
- Taken is four identity strings on an App Intent that must run in the app process. If it ran in the extension it fails closed.
- No distinctive IDs on purpose. Coverage would fail `check-ui-coverage.py --fail-uncovered` if SpringBoard IDs were added and never tapped.
- The widget is not a fifth tab. Bottom nav stays Cycle, Month, Trends, More.
