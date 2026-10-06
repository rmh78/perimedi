# Home Screen today's-meds widget

Home Screen widget for today's untaken medications. The capsule says Take or Nehmen. While a medication is still to take, the helper reads "Still to take today" or "Heute noch einnehmen". After the last dose is the brief check, that line keeps its height and the text is blank. The check capsule stays as wide as Take or Nehmen. After a widget tap the capsule shows a check briefly, then the row leaves. A Cycle take or a reminder take does not show that check.

## Sub-features

- Occupied card: today's pending medications (overdue included, reminder-off included), each with its form icon in a medication-color ring and a white Take or Nehmen label on that medication color, stacked with `+N` when more than one remains
- Helper under the PeriMedi title while a medication is still to take. After the last dose is the brief check, the line keeps its height and the text is blank
- Brief check on that same capsule after a widget tap. The check stays as wide as Take or Nehmen, then the row leaves. The check is not a button and does not say Taken or Genommen
- Empty card when nothing is pending today. "All taken for today" / "Heute alles genommen" when today had doses. "Nothing to take today" / "Heute nichts zu nehmen" when nothing was planned. No helper.
- Take marks every remaining pending slot for that medication on today
- Chrome follows the in-app language (en/de); medication name and dose label stay user text

## How to get to it (user POV)

Long-press the PeriMedi icon and choose one widget size. That replaces the icon with the widget. Long-press the widget and choose the app-icon chip to put the icon back. The app must have launched at least once so it can publish the snapshot. The Take tap may or may not open the app. Cycle shows that medication taken for today.

## Driving it with A11yID / AppRobot

`WidgetJourneyTests.testWidgetTakenUntakenAndEmptyMessage` drives the medium widget by visible labels (medication name, `Take`, `Still to take today`, the check, `All taken for today` / `Heute alles genommen`, `Mittelgroßes Widget`, `Medium-sized widget`, `App-Symbol`, `App icon`). `testSmallWidgetTakeInEnglishAndGerman` drives `Kleines Widget` / `Small` in English and German (`Nehmen`, `Heute noch einnehmen` before the tap) and asserts the check with the helper text blank. `testGermanMediumCheckBesidePending` drives a German medium card with two rows, a long name, `1 Hub`, and a light capsule. They press Home. If PeriMedi is not on that page, the suite looks one page toward the later icons and one page toward the first page, then stops. It does not swipe toward the App Library. SpringBoard still has no `A11yID`. Do not add widget identifiers. A signed run writes `ios/docs/widget-take/*.png`.

Local `control-perimedi verify` runs these journeys with the other UI tests. The GitHub `ui` job skips `WidgetJourneyTests` until issue 70 reworks them. The build signs the App Group. Do not pass `CODE_SIGNING_ALLOWED=NO`.

Proof is those journeys plus domain and the reminder Taken journey:

- `TodayPendingMedsTests` for today's list (today not tomorrow, group two times, taken drops, reminder-off, pause, empty)
- `DoseWidgetSnapshotTests` for the snapshot face (check window, blank helper after the last check, helper text while another medication remains, all-taken versus nothing planned, capsule contrast)
- `NextPendingDoseTests` for reminder `resolve` (pending, already taken, missing)
- `testDoseReminderTaken` for reminder Taken through `Store.setDoseStatus` and Cycle `taken`

## Gotchas

- The widget reads App Group JSON only. It does not call `TodayPendingMeds.list` and does not open SwiftData.
- Take is `medicationId` only on an App Intent. The tap may leave the Home Screen in front. If the intent is not hosted by the app it fails closed and does not write the log or the snapshot.
- Today only: `visible(at:)` shows `meds` when the device date matches `date`, or `nextMeds` after midnight until the app republishes. It never shows a later day as the visible list. The brief check does not appear on tomorrow's rows.
- `CODE_SIGNING_ALLOWED=NO` never stamps `group.app.perimedi.ios`. `containerURL` is nil, `publish` cannot write `next-dose.json`, and the widget shows the missing-file empty chrome (`Heute nichts zu nehmen` / `Nothing to take today`) even when Cycle has pending slots. Local `verify` signs that group and runs `WidgetJourneyTests` in the same `xcodebuild test` as the other UI tests. The GitHub `ui` job skips that class.
- No distinctive IDs on purpose. Coverage would fail `check-ui-coverage.py --fail-uncovered` if SpringBoard IDs were added and never tapped.
- The widget is not a fifth tab. Bottom nav stays Cycle, Month, Trends, More.
- Home can open the page that holds the test runner. If the PeriMedi icon or widget is not on that page, the journey looks one page toward the later icons and one page toward the first page, then stops. It does not continue to the App Library. Pressing an off-screen icon scrolls SpringBoard.
- The size menu reads `Small widget`, `Medium-sized widget`, and `App icon` on the iOS 26.5 simulator. A German simulator and older menus use `Kleines Widget`, `Mittelgroßes Widget`, `App-Symbol`, and the shorter English names. The journey accepts each of those. The journey leaves SpringBoard alone when it is already running. Terminating that live shell and launching on the first Maps or Karten hit fails with host down. When the shell is down, the journey waits until Maps or Karten stays available. A missing SpringBoard snapshot is retried. The PeriMedi widget is read as any element. Reading it as an Icon fails the test when SpringBoard reports SBWidgetIcon as Other. A Take or Nehmen tap accepts only a capsule-sized frame on the current page. The small widget’s capsule sits on the left. A frame the size of the screen is not the capsule. Tear-down looks one page each way, then long-presses the widget and chooses the app-icon chip. It does not continue to the App Library. It does not fail the test.
