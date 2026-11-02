# UI flow budget

One English walk, one app launch. Each row is one run. Nightly full job [41351455722](https://github.com/rmh78/perimedi/actions/runs/41351455722). PR ui job [41351442718](https://github.com/rmh78/perimedi/actions/runs/41351442718). Durations are the XCTest `t =` clock. A top-level line has one space after the timestamp. Nested lines are not added again.

The body target is 180 seconds. The PR ui job target is 360 seconds. The table sums to 86.5 seconds, so the body fits. Two local verifies printed `verify: ok`. The bodies were 79.087 seconds and 62.876 seconds. The band around 86.5 is 69.2 to 103.8. The second run is under that band. On that run the lane existed 15.7 seconds after the med tap (t=14.84 to t=30.54). The period sheet was open at t=30.89 and gone at t=35.84, which is 5.0 seconds. Later `sheet.period` lines, including t=45.46, are the More scroll looking for an open sheet. The 35.7 second type row and the 12.4 second period row stay in the table as ceilings. The targets stay 180 and 360. The type row is the cold PR run. The nightly smoke ran second and reached the lane 13.9 seconds after the med tap (t=10.14 to t=24.02). A warm rerun can be about 22 seconds faster on that one row. The same PR job spent 563 seconds of wall time on a 71.317 second test. Overhead is 491.683 seconds. Adding this table makes 578.183 seconds. The job does not fit. A zero-second test on that overhead is still 491.683 seconds. Cutting more rows does not move the job under 360 seconds.

```budget
body-target-s: 180
job-target-s: 360
measured-pr-job-s: 563
measured-pr-smoke-s: 71.317
job-fits: no
```

## Flow

Settings is the More tab. Export is a button on that tab, so the flow opens More and then the preview. The written list had those two the other way around. One visit covers both.

The symptom row taps one score. The log tapped three. The seconds are the three-score span minus the two extra scores.

| Step | Seconds | Source run | Covers |
| --- | ---: | --- | --- |
| Launch to empty home | 14.7 | Nightly `testEnglishAppJourney`. Open at t=0.70. Find `cycle.empty.meds` at t=15.42. | `tab.cycle`, `cycle.empty.meds` |
| Type one medication | 35.7 | PR `testEnglishSmoke`. Tap `cycle.action.med` at t=19.75. Lane at t=70.78. Span 51.03s. Minus the keyboard spin from t=31.18 to t=46.55 (15.37s, left out). That run also opened the type menu. The flow leaves Every day, Pill, and 20:00 selected, so 35.7s is a ceiling. | `med.name`, `med.dose`, `med.save`, `cycle.lane.estrogen` |
| Log one period | 12.4 | Nightly app journey. Tap `cycle.action.period` at t=18.87. `period.add` is back at t=31.25. That span includes two date edits. The flow saves the card as it opens (today, no end, medium flow), so 12.4s is a ceiling. | `period.add`, `period.save`, `sheet.period` |
| Log one symptom | 5.3 | Nightly app journey. Tap `cycle.action.symptom` at t=282.46. Close at t=293.87. Span 11.41s with three scores. Drop the sleep score (t=284.82 to t=287.62, 2.80s) and the joints score (t=287.62 to t=290.95, 3.33s). | `symptom.score.hot_flash.3`, `sheet.symptom` |
| Open Month | 1.1 | Nightly app journey. Tap `tab.month` at t=297.58. `month.day.2026-03-15` exists at t=298.65. | `tab.month`, `month.day` |
| Open Trends | 2.1 | Nightly app journey. Tap `tab.trends` at t=15.93. Back to Cycle at t=17.99. Empty store. A chart with scores used a second launch and is not in this flow. | `tab.trends`, `trends.status` |
| Open Settings | 1.2 | Nightly app journey. Tap `tab.more` at t=316.32. `more.lang.en` exists at t=317.52. | `tab.more`, `more.lang.en` |
| Export preview | 3.0 | Nightly app journey. Tap `more.sharePdf` at t=328.93. `visit.pdf.preview` exists at t=331.92. | `more.sharePdf`, `visit.range.continue`, `visit.pdf.preview` |
| Install the medium widget | 4.4 | Nightly `testEnglishWidgetJourney`. Home at t=8.70. Tap `Medium-sized widget` at t=13.07. | Home, app icon, `Medium-sized widget` |
| Widget Take | 1.2 | Nightly widget journey. Home at t=48.98 onto an installed widget. `Take` exists at t=50.14. The button query succeeded. Other-element queries were already failing. Time from the size tap to the first Take is not a separate clean span. | `Take` |
| App shows that Take | 1.0 | Nightly widget journey, medium face. Open app at t=56.43. Lane status found at t=57.41. | lane status `taken` |
| Restore the app icon | 4.4 | Same Home, long-press, and chip tap as the install row, t=8.70 to t=13.07, in reverse. A healthy restore was not its own span. | App icon |

## Left out

These rows are not in the sum.

| Step | Seconds | Source run | Why it is out |
| --- | ---: | --- | --- |
| In-app Take | 2.7 | Nightly app journey. Lane exists at t=228.85. Taken status at t=231.58. | The dose stays pending. The widget Take is the one Take. |
| Untake on Cycle | 1.4 | Nightly app journey. Status at t=231.58. Status after the lane tap at t=232.96. | That tap only put back the dose the in-app Take had just taken. |
| Keyboard spin after the sheet tap | 15.4 | PR smoke, t=31.18 to t=46.55. | `dismissKeyboard` polls `keyboard.exists`. The flow taps the sheet and waits for the next field. |
| Second period, edit, and delete | 149.6 | Nightly app, t=31.54 to t=181.12. Includes the 56.1s gap at the t=62.91 tap on `5`. | Repeated period work. One card stays. |
| Second medication | 32.7 | Nightly app, med tap t=236.51 to save t=269.19. | One medication is enough for Take and the widget. |
| Snooze | 1.6 | Nightly app, untake tap t=231.84 to snooze tap t=233.46. | The flow leaves the pending dose alone. |
| Language and reminder controls | 11.1 | Nightly app, `more.lang.de` at t=317.88 to `more.sharePdf` at t=328.93. | German stays in the screenshot catalog. The flow does not toggle reminders. |
| Month pager | 15.1 | Nightly app, `month.pager.next` at t=301.25 to `tab.more` at t=316.32. | The flow only opens the month. |
| Accessibility failure bucket | 47.4 | Nightly widget. Reported 147.544s. Last top-level line t=100.17. | 888 `kAXErrorServerNotFound` lines from t=14.07, process 33784. The next query after the size tap is `Other (First Match)`, which is `springboard.descendants(matching: .other)` in `widgetIcon()`. The flow waits on the Take button and does not run that query. |

## Job overhead

PR ui job 124983310781 started at 2026-11-01T21:23:36Z and completed at 2026-11-01T21:32:59Z. Wall time is 563 seconds. `testEnglishSmoke` reported 71.317 seconds. Overhead is 491.683 seconds. Cache restore was an exact hit. No xcresult was uploaded.

| Piece | Seconds | Clock |
| --- | ---: | --- |
| Checkout through plugin cache | 26 | 21:23:36Z to 21:24:02Z |
| Boot step | 153 | 21:24:02Z to 21:26:35Z. `simctl boot` returned by 21:24:09Z. `bootstatus` then ran until 21:26:34Z and printed `Device already booted, nothing to do.` |
| UI step before `xcodebuild` exec | 115 | 21:26:35Z to 21:28:30Z. Includes about 40s before the verify script prints env, then device lookup and the suite filter (21:28:07Z to 21:28:29Z). |
| `xcodebuild` until the runner prints `Running tests...` | 132 | Exec 21:28:30Z. Embedded runner clock 21:30:42Z. The log line is flushed at 21:31:20Z. |
| Test body | 71.3 | Reported 71.317s. |
| After the test, until the job completes | 66 | UI step ends 21:32:47Z. Job completes 21:32:59Z. The 132s and the 71s overlap this step, so this row is the tail only. |

Nightly bootstatus on the same script was 68 seconds (21:20:33Z to 21:21:41Z). Nightly `xcodebuild` reached `Running tests...` in 25 seconds (exec 21:24:10Z, runner 21:24:35Z). Both spreads are one pair of runs. Removing `bootstatus` on the PR clock would leave 578.183 minus 145, which is 433.183 seconds, still over 360. The package-resolution flags already on that command did not remove the 132 second lead-in. Neither cut is a demonstrated way under 360 seconds.

`scripts/ui-budget` reprints the table sum, the overhead, and the job verdict. It reads `ios/DerivedData/PeriMedi.xcresult` when that bundle exists.
