# UI flow budget

One English walk, one app launch. Each row is one run. Nightly full job [41351455722](https://github.com/rmh78/perimedi/actions/runs/41351455722). PR ui job [41351442718](https://github.com/rmh78/perimedi/actions/runs/41351442718). Durations are the XCTest `t =` clock. A top-level line has one space after the timestamp. Nested lines are not added again.

The flow table sums to 90.6 seconds. Local verifies printed `verify: ok`. The bodies were 79.087 seconds, 62.876 seconds, and 59.619 seconds. The 79.087 second run is inside 72.5 to 108.7 seconds. The 62.876 second run and the 59.619 second run are under that span. Those three local bodies did not include the 4.1 seconds of Cycle Taken and Untake. A later local verify printed `verify: ok` with `testUserFlow` at 100.904 seconds, including those taps. That body is inside the same span. On the 62.876 second run the lane existed 15.7 seconds after the med tap (t=14.84 to t=30.54). The period sheet was open at t=30.89 and gone at t=35.84, which is 5.0 seconds. Later `sheet.period` lines, including t=45.46, are the More scroll looking for an open sheet. The 35.7 second type row and the 12.4 second period row stay in the table as ceilings. The type row is the cold PR run. The nightly smoke ran second and reached the lane 13.9 seconds after the med tap (t=10.14 to t=24.02). A warm rerun can be about 22 seconds faster on that one row. The same PR job spent 563 seconds of wall time on a 71.317 second test. Overhead is 491.683 seconds. Adding this table makes 582.283 seconds.

```budget
body-s: 90.6
warm-wall-s: 750
warm2-wall-s: 617
paper-s: 449
```

## Flow

Settings is the More tab. Export is a button on that tab, so the flow opens More and then the preview. The written list had those two the other way around. One visit covers both.

The symptom row taps one score. The log tapped three. The seconds are the three-score span minus the two extra scores.

| Step | Seconds | Source run | Covers |
| --- | ---: | --- | --- |
| Launch to empty home | 14.7 | Nightly `testEnglishAppJourney`. Open at t=0.70. Find `cycle.empty.meds` at t=15.42. | `tab.cycle`, `cycle.empty.meds` |
| Type one medication | 35.7 | PR `testEnglishSmoke`. Tap `cycle.action.med` at t=19.75. Lane at t=70.78. Span 51.03s. Minus the keyboard spin from t=31.18 to t=46.55 (15.37s, left out). That run also opened the type menu. The flow leaves Every day, Pill, and 20:00 selected, so 35.7s is a ceiling. | `med.name`, `med.dose`, `med.save`, `cycle.lane.estrogen` |
| In-app Take | 2.7 | Nightly app journey. Lane exists at t=228.85. Taken status at t=231.58. | `cycle.lane.estrogen` status `taken` |
| Untake on Cycle | 1.4 | Nightly app journey. Status at t=231.58. Status after the lane tap at t=232.96. | lane status `not-taken` |
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
| Keyboard spin after the sheet tap | 15.4 | PR smoke, t=31.18 to t=46.55. | `dismissKeyboard` polls `keyboard.exists`. The flow taps the sheet and waits for the next field. |
| Second period, edit, and delete | 149.6 | Nightly app, t=31.54 to t=181.12. Includes the 56.1s gap at the t=62.91 tap on `5`. | Repeated period work. One card stays. |
| Second medication | 32.7 | Nightly app, med tap t=236.51 to save t=269.19. | One medication is enough for Take and the widget. |
| Snooze | 1.6 | Nightly app, untake tap t=231.84 to snooze tap t=233.46. | The flow does not snooze. |
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

Nightly bootstatus on the same script was 68 seconds (21:20:33Z to 21:21:41Z). Nightly `xcodebuild` reached `Running tests...` in 25 seconds (exec 21:24:10Z, runner 21:24:35Z). Both spreads are one pair of runs. Removing `bootstatus` on the PR clock would leave 582.283 minus 145, which is 437.283 seconds. The package-resolution flags already on that command did not remove the 132 second lead-in.

## Warm exact hit

One exact cache hit on the PR that merged as a99010e. Run [41527086840](https://github.com/rmh78/perimedi/actions/runs/41527086840), ui job [125767194224](https://github.com/rmh78/perimedi/actions/runs/41527086840/job/125767194224), SHA eefb015, attempt 3. The job started at 2026-11-03T06:36:13Z and completed at 2026-11-03T06:48:43Z. `testUserFlow` passed in 226.994 seconds. The derived-data key was an exact hit. The drop-marker, prune, and save steps were skipped. Attempt 4 is the repeat.

| Step | Seconds | Clock |
| --- | ---: | --- |
| Checkout | 8 | Job start 06:36:13Z through checkout end 06:36:21Z. Includes set up job. |
| Cache restore | 11 | 06:36:21Z to 06:36:32Z. Xcode version, derived data, and the plugin cache. Exact hit. |
| Boot | 90 | Step 06:36:32Z to 06:38:02Z. `simctl boot` at 06:36:37Z. `bootstatus` from 06:36:39Z to 06:37:55Z printed `Device already booted, nothing to do.` |
| Gap before the UI step | 2 | 06:38:02Z to 06:38:04Z. |
| Before xcodebuild | 81 | UI step start 06:38:04Z to exec 06:39:25Z. Skip mtime at 06:38:48Z. Reused cached build at 06:38:55Z. Already booted at 06:39:00Z. |
| Install | 0 | No `simctl install` line. The time sits inside xcodebuild start. |
| xcodebuild start | 288 | Exec 06:39:25Z to test start 06:44:13Z. The runner printed `Running tests...` at 06:43:55Z. The flushed lines have no SwiftCompile. |
| Test body | 227 | Reported 226.994s, from 06:44:13Z. From t=109.57 to t=200.58 is 91 seconds of existence retries on `cycle.lane.estrogen` after the widget Take. |
| Teardown | 31 | 06:48:00Z to UI step end 06:48:31Z. Catalog at 06:48:04Z. Shutdown mark 06:48:19Z. `verify: ok` at 06:48:30Z. |
| Complete job | 12 | 06:48:31Z to 06:48:43Z. Note a successful build, post checkout, and Complete job. |

## Second warm exact hit

Same run, attempt 4, ui job [125775893870](https://github.com/rmh78/perimedi/actions/runs/41527086840/job/125775893870). The job started at 2026-11-03T07:02:21Z and completed at 2026-11-03T07:12:38Z. `testUserFlow` passed in 198.800 seconds. The same derived-data key was an exact hit. Drop-marker, prune, and save were skipped.

| Step | Seconds | Clock |
| --- | ---: | --- |
| Checkout | 7 | Job start 07:02:21Z through checkout end 07:02:28Z. |
| Cache restore | 11 | 07:02:28Z to 07:02:39Z. Exact hit. |
| Boot | 56 | 07:02:39Z to 07:03:35Z. `simctl boot` at 07:02:43Z. `bootstatus` at 07:02:45Z. `Finished` at 07:03:34Z. |
| Before xcodebuild | 43 | UI step 07:03:35Z to exec 07:04:18Z. Skip mtime at 07:03:55Z. Reused cached build at 07:04:10Z. |
| Install | 0 | No `simctl install` line. The time sits inside xcodebuild start. |
| xcodebuild start | 127 | Exec 07:04:18Z to test start 07:06:25Z. `Running tests...` at 07:06:12Z. The flushed lines have no SwiftCompile. |
| Test body | 199 | Reported 198.800s. From t=111.21 to t=188.27 is 77 seconds of existence retries on `cycle.lane.estrogen` after the widget Take. |
| Teardown | 165 | Test end 07:09:44Z to UI step end 07:12:29Z. Catalog at 07:09:51Z. Shutdown mark at 07:12:08Z. Orphans cleared at 07:12:28Z. |
| Complete job | 9 | 07:12:29Z to 07:12:38Z. |

## Paper cuts

The paper uses the faster wall, 617 seconds. Overlap hides the 11 second cache restore inside boot. Skip removes `simctl uninstall` and the simulator shutdown. On this run the catalog finished at 07:09:51Z and orphans cleared at 07:12:28Z, which is 157 seconds. The runner VM is discarded after the job. Local verify still uninstalls. The lane retry stays in #150, so it is not a cut in this table.

| Cut | Seconds | Where |
| --- | ---: | --- |
| Overlap cache restore with boot | -11 | The cache restore is the shorter step. |
| Skip CI uninstall and shutdown | -157 | Catalog 07:09:51Z to orphans cleared 07:12:28Z on the faster run. |

The paper sum is 449 seconds. Checkout, boot, the preamble, xcodebuild start, and the test body on that run are 7 + 56 + 43 + 127 + 199, which is 432 seconds, before teardown and Complete job. xcodebuild started at 07:04:18Z, after boot ended at 07:03:35Z. Those rows stay in sequence.

`scripts/ui-budget` sums the flow table, both warm tables, and the paper cuts. It checks each fence. It reads `ios/DerivedData/PeriMedi.xcresult` when that bundle exists.
