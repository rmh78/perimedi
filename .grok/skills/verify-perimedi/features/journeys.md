# First-use journey

A new user opens an empty app, types one medication, saves the new period card as it opens, logs one symptom, opens Month, Trends, and More, opens the visit preview, and takes the still-pending dose once on the medium Home Screen widget.

## Sub-features

- `first-use-empty` empty Cycle (`cycle.empty.meds` contains `need-med`)
- `first-use-meds` one everyday estrogen lane
- `first-use-taken` one widget Take that the lane reads as `taken`. The dose stays pending until that tap.
- `first-use-period` one period saved in the current month
- `first-use-symptom` hot flash 3 shows `cycle.chip.score.hot_flash`
- `first-use-month` today's month cell `month.day.{device date}`

## How to get to it (user POV)

Launch the app on a clear store. Sheets open over Cycle, not as extra pages. The same launch later opens Month, Trends, More, and the Home Screen.

## Driving it with A11yID / AppRobot

Preconditions:

- `control-perimedi --run-id "$RUN_ID" doctor` prints `doctor: ok` after launch.
- `testUserFlow` launches `JourneyLaunch.userFlow` (`-en -clear -uiTesting -today=<device date>`). One launch. No `-journeyStep`, no `-loadSample`, no `-fixture=trends`, no `-remindIn`.

- **Empty home.** `AppRobot.launch` waits for `tab.cycle` and `cycle.action.med`. `cycle.empty.meds` contains `need-med`.
- **Meds.** `addMedication` types Estrogen and `1 mg`, then saves. The sheet stays on Pill, Every day, and 20:00. `cycle.lane.estrogen` exists. The dose stays pending.
- **Period.** Open the new card and save it. Start is the selected day, the end stays empty, and the flow stays medium. Close `sheet.period`.
- **Symptom.** Tap `symptom.score.hot_flash.3`. `cycle.chip.score.hot_flash` exists. The flow does not read the chip value.
- **Month.** Tap `tab.month`. `month.day.` plus the device date exists. No pager.
- **Trends.** Tap `tab.trends`. `trends.status` exists. The flow does not read its value and does not launch a chart fixture.
- **More.** Tap `tab.more`. Scroll to `more.sharePdf`, continue from `visit.range`, wait for `visit.pdf.preview` and `visit.pdf.share`, then close. Do not tap Share. The catalog waits for `more.sample` after its own preview.
- **Widget.** Tap `tab.cycle` so the lane is on screen, then Home. Long-press the app icon, tap `Medium-sized widget`, tap `Take` once. Activate the app. The resumed screen is Cycle, and `cycle.lane.estrogen.status` is `taken`. Tear-down restores the app icon when the slot is a widget.
- **Proof.** `control-perimedi --run-id "$RUN_ID" drive --test PeriMediUITests/RequiredJourneyTests/testUserFlow`. Evidence is `TEST SUCCEEDED`.

## Gotchas

- The flow does not switch language, snooze, page Month, add a second medication, or launch again. Catalog pictures still cover German More, the chart, and the largest-text More picture.
- Typing must use the software keyboard. The driver turns Connect Hardware Keyboard off before boot. `clearAndType` taps the sheet to leave the keyboard. It does not query `keyboard.exists`.
- The flow does not load the sample. The catalog scrolls to `more.sample` after its visit preview and does not tap it.
- SpringBoard queries in this flow use `icons` and `buttons` only. A query of other elements after the size tap is what killed the accessibility server on the nightly widget run.
