# Home Screen today's-meds widget

Home Screen widget for today's untaken medications. The capsule says Take or Nehmen. While a medication is still to take, the helper reads "Still to take today" or "Heute noch einnehmen". After the last dose is the brief check, that line keeps its height and the text is blank. The check capsule stays as wide as Take or Nehmen. The check is visible at the Take tap, before the doses finish recording, then the row leaves. A Cycle take or a reminder take does not show that check.

## Sub-features

- Occupied card: today's pending medications (overdue included, reminder-off included), each with its form icon in a medication-color ring and a white Take or Nehmen label on that medication color, stacked with `+N` when more than one remains
- Helper under the PeriMedi title while a medication is still to take. After the last dose is the brief check, the line keeps its height and the text is blank
- Check visible at the Take tap, before the doses finish recording. It stays as wide as Take or Nehmen, then the row leaves. The check is not a button and does not say Taken or Genommen. A Cycle take or a reminder take does not show it
- Empty card when nothing is pending today. "All taken for today" / "Heute alles genommen" when today had doses. "Nothing to take today" / "Heute nichts zu nehmen" when nothing was planned. No helper.
- Take marks every remaining pending slot for that medication on today
- Chrome follows the in-app language (en/de); medication name and dose label stay user text

## How to get to it (user POV)

Long-press the PeriMedi icon and choose one widget size. That replaces the icon with the widget. Long-press the widget and choose the app-icon chip to put the icon back. The app must have launched at least once so it can publish the snapshot. The Take tap may or may not open the app. Cycle shows that medication taken for today.

## Driving it with A11yID / AppRobot

`testUserFlow` is the one proof. The app is already running with Estrogen `1 mg` everyday. The flow taps that Cycle lane once so the status reads `taken`, taps it again so the status reads `not-taken`, and the lane is `not-taken` before Home Screen. The Take intent can bring the app forward, and it resumes on the tab that was open. The flow presses Home, long-presses the PeriMedi app icon, taps `Medium-sized widget` (or `Mittelgroßes Widget`), and taps `Take` (or `Nehmen`) once. It does not read helper copy, does not change size, and does not write `widget-medium-before-en.png` or `widget-medium-after-en.png`. Those two pictures stay committed files. It activates the app and `assertStatus` reads the word Taken and the token `taken` on `cycle.lane.estrogen.status`. Tear-down presses Home. If the app icon is already back, it returns. If the slot is the widget, it long-presses and taps `App icon` or `App-Symbol`. If neither icon is ready, it returns and does not fail the test. SpringBoard still has no `A11yID`. Do not add widget identifiers. Queries stay on `icons` and `buttons`.

A pull request runs this step inside `testUserFlow`. Local `verify` and the nightly full suite run the same test. The build signs the App Group. Do not pass `CODE_SIGNING_ALLOWED=NO`.

Domain proof stays next to that step:

- `TodayPendingMedsTests` for today's list (today not tomorrow, group two times, taken drops, reminder-off, pause, empty)
- `DoseWidgetSnapshotTests` for the snapshot face (check window, blank helper after the last check, helper text while another medication remains, all-taken versus nothing planned, capsule contrast)
- `NextPendingDoseTests` for reminder `resolve` (pending, already taken, missing)
- `testUserFlow` for the Cycle Taken tap and the one medium widget Take. `assertStatus` reads the word Taken and the token `taken` after the Cycle tap, the word Not taken and `not-taken` after the put-back, and Taken and `taken` after the widget Take.

## Gotchas

- The widget reads App Group JSON only. It does not call `TodayPendingMeds.list` and does not open SwiftData.
- If the snapshot is not stored, publish does not reload timelines, and the previous face stays until a later publish stores one.
- Take is `medicationId` only on an App Intent. The tap may leave the Home Screen in front. If the intent is not hosted by the app it fails closed and does not write the log or the snapshot.
- Today only: `visible(at:)` shows `meds` when the device date matches `date`, or `nextMeds` after midnight until the app republishes. It never shows a later day as the visible list. The brief check does not appear on tomorrow's rows.
- `CODE_SIGNING_ALLOWED=NO` never stamps `group.app.perimedi.ios`. `containerURL` is nil, `publish` cannot write `next-dose.json`, and the widget shows the missing-file empty chrome (`Heute nichts zu nehmen` / `Nothing to take today`) even when Cycle has pending slots. `verify` signs that group and runs `testUserFlow` on the booted iPhone 17e.
- No distinctive IDs on purpose. Coverage would fail `check-features.py` if SpringBoard IDs were added and never tapped.
- The widget is not a fifth tab. Bottom nav stays Cycle, Month, Trends, More.
- Home can open the page that holds the test runner. The flow does not page and does not open the App Library. It waits for the PeriMedi icon on the current page.
- The size menu the flow taps is `Medium-sized widget` or `Mittelgroßes Widget`. Restore taps `App icon` or `App-Symbol`. The flow leaves SpringBoard alone when it is already running. It does not terminate the shell. After the size tap it queries `buttons` only. A zero icon frame is inside 0...1, so that coordinate press hits the screen corner. The press uses the frame captured while the icon exists and is on screen, and otherwise presses the icon element. A missing icon throws if its frame is read. After Take the icon is a widget, so restore checks that the element exists before reading the frame. On the nightly widget run, the first `descendants(matching: .other)` after that tap returned `kAXErrorServerNotFound` for the new widget process. Do not query other elements there, and do not swallow that error.
