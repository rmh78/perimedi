# First-use journey

A new user opens an empty app, glances at empty Trends, logs a period, adds medications, marks a dose taken, notes a symptom, checks that Month agrees, and opens a period day back on Cycle.

## Sub-features

- `first-use-empty` empty Cycle (intro + `need-period` / `need-med`) and empty Trends (`need-cycles`)
- `first-use-period` last period logged; strip days contain `period`; intro gone
- `first-use-meds` everyday estrogen and cyclic progesterone lanes
- `first-use-taken` this morning's estrogen marked `taken`
- `first-use-symptom` hot flash 3 shows `cycle.chip.score.hot_flash` containing `strong`
- `first-use-month` Month tokens for selected / period / taken / symptom, pager next/prev, period day back on Cycle

## How to get to it (user POV)

Launch the app on a clear store. Stay on Cycle except for the empty Trends glance and the Month check. Sheets open over Cycle, not as extra pages.

## Driving it with A11yID / AppRobot

Preconditions:

- `control-perimedi --run-id "$RUN_ID" doctor` prints `doctor: ok` after launch.
- Journey launch flags only: `-en -clear -today=2026-03-15 -uiTesting`. No `-journeyStep`, no `-loadSample`.

- **Empty home.** `AppRobot.launch()` waits for `tab.cycle` and `cycle.action.med`. `cycle.empty.meds` contains `need-period` and `need-med`. `cycle.intro` is present. No `cycle.lane.estrogen`. No `cycle.effect`.
- **Empty Trends.** Tap `tab.trends`. `trends.status` and `trends.empty` are `need-cycles`. Return with `tab.cycle`.
- **Period.** `AppRobot.addPeriod()` (`2026-03-07`–`2026-03-11`). Strip days contain `period`. Empty-meds value is exactly `need-med`. `cycle.effect` is `no-previous`.
- **Meds.** `addMedication` Estrogen `1 mg` everyday, Progesterone `200 mg` Cream cyclic, start `2026-03-07`. Lanes `cycle.lane.estrogen` and `cycle.lane.progesterone` exist. Empty-meds gone.
- **Taken.** Tap `cycle.lane.estrogen`. `cycle.lane.estrogen.status` is `taken`.
- **Pager.** `cycle.pager.prev` changes `cycle.pager.label`; `cycle.pager.today` restores it. Period chip exists after paging back.
- **Symptom.** `addSymptom()` then `cycle.chip.score.hot_flash` contains `strong`.
- **Month.** Tap `tab.month`. Today contains `selected`, `taken`, `symptom`. Period start contains `period`. `month.pager.next` shows `month.day.2026-04-01`. Select period start, `tab.cycle`, strip day is hittable in the plot.
- **Proof.** `control-perimedi --run-id "$RUN_ID" drive --test PeriMediUITests/FirstUseJourneyTests/testFirstUseJourney`. Evidence `TEST SUCCEEDED` plus the assertions above.

## Gotchas

- This path spans Cycle, Trends empty, period sheet, medication sheet, symptom sheet, and Month. It does not prove More, visit PDF, backup confirm, or the Trends chart fixture.
- Typing must use the software keyboard. The driver turns Connect Hardware Keyboard off before boot.
- Sample data is a More action, not this journey.
