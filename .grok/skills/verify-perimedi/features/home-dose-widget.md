# Home Screen today's-meds widget

Home Screen widget for today's untaken medications. The capsule says Take or Nehmen. While a medication is still to take, the helper reads "Still to take today" or "Heute noch einnehmen". After a widget tap the capsule shows a check briefly, then the row leaves. A Cycle take or a reminder take does not show that check.

## Sub-features

- Occupied card: today's pending medications (overdue included, reminder-off included), each with its form icon in a medication-color ring and a white Take or Nehmen label on that medication color, stacked with `+N` when more than one remains
- Helper under the PeriMedi title only while at least one row is still Take
- Brief check on that same capsule after a widget tap, then the row leaves; the check is not a button and does not say Taken or Genommen
- Empty card when nothing is pending today (another day's doses do not appear): empty title only, no helper
- Take marks every remaining pending slot for that medication on today
- Chrome follows the in-app language (en/de); medication name and dose label stay user text

## How to get to it (user POV)

Long-press the PeriMedi icon and choose one widget size. That replaces the icon with the widget. Long-press the widget and choose the app-icon chip to put the icon back. The app must have launched at least once so it can publish the snapshot. The Take tap may or may not open the app. Cycle shows that medication taken for today.

## Driving it with A11yID / AppRobot

`WidgetJourneyTests.testWidgetTakenUntakenAndEmptyMessage` drives the medium widget by visible labels (medication name, `Take`, `Still to take today`, `Nothing to take today` / `Heute nichts zu nehmen`, `Mittelgroßes Widget`, `App-Symbol`). `testSmallWidgetTakeInEnglishAndGerman` drives `Kleines Widget` / `Small` in English and German (`Nehmen`, `Heute noch einnehmen`). Both press Home. If PeriMedi is not on that page, the suite swipes once toward the first page and stops. It does not swipe toward the App Library. SpringBoard still has no `A11yID`. Do not add widget identifiers. A signed run writes `ios/docs/widget-take/*.png`.

The journey needs a signed App Group. Unsigned `verify` passes `-skip-testing:PeriMediUITests/WidgetJourneyTests`.

Proof is that journey plus domain and the reminder Taken journey:

- `TodayPendingMedsTests` for today's list (today not tomorrow, group two times, taken drops, reminder-off, pause, empty)
- `NextPendingDoseTests` for reminder `resolve` (pending, already taken, missing)
- `testDoseReminderTaken` for reminder Taken through `Store.setDoseStatus` and Cycle `taken`

## Gotchas

- The widget reads App Group JSON only. It does not call `TodayPendingMeds.list` and does not open SwiftData.
- Take is `medicationId` only on an App Intent. The tap may leave the Home Screen in front. If the intent is not hosted by the app it fails closed and does not write the log or the snapshot.
- Today only: `visible(at:)` shows `meds` when the device date matches `date`, or `nextMeds` after midnight until the app republishes. It never shows a later day as the visible list. The brief check does not appear on tomorrow's rows.
- Unsigned Simulator (`CODE_SIGNING_ALLOWED=NO`) never stamps `group.app.perimedi.ios`. `containerURL` is nil, `publish` cannot write `next-dose.json`, and the widget shows the missing-file empty chrome (`Heute nichts zu nehmen` / `Nothing to take today`) even when Cycle has pending slots. Local install must be signed (no `CODE_SIGNING_ALLOWED=NO`). `control-perimedi verify` stays unsigned on purpose.
- No distinctive IDs on purpose. Coverage would fail `check-ui-coverage.py --fail-uncovered` if SpringBoard IDs were added and never tapped.
- The widget is not a fifth tab. Bottom nav stays Cycle, Month, Trends, More.
- Home can open the page that holds the test runner. The journey then swipes once toward the first page, where the PeriMedi icon or widget sits. It does not swipe toward the App Library. Pressing an off-screen icon scrolls SpringBoard.
- A failed journey still puts the app icon back. Tear-down taps the app-icon chip if the size menu is open, otherwise long-presses the widget and chooses that chip. It does not fail the test. The next run starts from the icon.
