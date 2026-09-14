---
name: verify-perimedi
description: Use when driving or checking PeriMedi iOS UI from an agent, proving Cycle/Month/Trends/More behavior, or for /verify-perimedi. Maps each surface to A11yID and AppRobot. Do not invent identifiers.
disable-model-invocation: true
---

# Verify PeriMedi

Native iOS app. Proof is XCUITest on an iPhone Simulator through `control-perimedi`, not markdown. Identifiers live in `ios/PeriMedi/App/A11yID.swift`. The in-test harness is `ios/PeriMediUITests/AppRobot.swift`. Read `features/` for the surface you are about to touch, then drive it.

`--run-id` plus the simulator UDID is the isolation handle. Require `--run-id` on every `control-perimedi` command. Do not pass `--checkout`. Refuse to drive a simulator that already has `app.perimedi.ios` installed unless this run-id holds the lock.

## Launch

Prefer **iPhone 17e**. If that simulator already has PeriMedi (a user session), set `SIM_DEVICE` to another available iPhone (often `iPhone 17`) or pass `SIM_UDID`. Override OS with `SIM_OS` (for example `26.5`). Journey tests that type into fields are proven on 17e; a different iPhone can fail `clearAndType` when the software keyboard does not appear.

```bash
.grok/skills/verify-perimedi/scripts/control-perimedi --run-id "$RUN_ID" launch
```

Ready when stdout contains `launch: ready udid=`. The helper boots that UDID if it was shut down, turns Connect Hardware Keyboard off (so `typeText` hits the software keyboard), freezes the status bar at 9:41, and uninstalls leftover PeriMedi **on that UDID only**. XCUITest launches the app per drive; there is no long-lived server. Booting a second simulator can leave the first Shutdown; if 17e was a user session, `xcrun simctl boot` that UDID again and do not uninstall it.

Teardown is `cleanup` on the same `--run-id`.

`AppRobot.launch()` always uses `-en -clear -today=2026-03-15 -uiTesting`. Never pass `-journeyStep` or `-loadSample` on journey tests. `ScreenCatalogTests` may pass `-loadSample`. Frozen dates in `UITestDate`: today `2026-03-15`, yesterday `2026-03-14`, period `2026-03-07`–`2026-03-11`.

## Doctor

Read-only. Run first, and again whenever anything looks off. A capture against a stale or foreign instance is not evidence.

```bash
.grok/skills/verify-perimedi/scripts/control-perimedi --run-id "$RUN_ID" doctor
```

Pass is a final `doctor: ok`. It checks Darwin/Xcode, the python rails (`check-feature-map.py`, `check-feature-layout.py`, `check-l10n-layout.py`, `check-domain-boundary.py`, `check-openspec-sync.py`, `check-ui-coverage.py --fail-uncovered`, `check-screen-catalog.py`), that this run-id owns the UDID lock after launch, that the sim is Booted, and that Connect Hardware Keyboard is false. It fails if PeriMedi is already installed on the target UDID without this run-id.

`bash ios/scripts/verify.sh` remains the full product doctor (domain tests + every UI test + uninstall). Use it for a PR-wide pass, not as the per-drive health check.

## Drive

1. Open the matching file under `features/`.
2. Get there the way a user would (bottom tabs, Cycle action buttons, sheets).
3. Tap `A11yID` strings through `AppRobot` (`tap`, `waitFor`, `value(of:)`, `exists`).
4. Type with `clearAndType` / `typeText`: tap, wait until the software keyboard exists, type once, assert the exact value. Do not paste, retry-loop `typeText`, use the clipboard menu, or test-only setters.
5. Assert the observable state listed in that file.

```bash
.grok/skills/verify-perimedi/scripts/control-perimedi --run-id "$RUN_ID" \
  drive --test PeriMediUITests/FirstUseJourneyTests/testFirstUseJourney
```

Mapped tests:

| Surface | `--test` |
|---|---|
| Cycle, period, med, symptom, Month | `PeriMediUITests/FirstUseJourneyTests/testFirstUseJourney` |
| More, visit PDF, backup rows (cancel) | `PeriMediUITests/FirstUseJourneyTests/testMoreRemindersControls` |
| Dose reminder Taken | `PeriMediUITests/FirstUseJourneyTests/testDoseReminderTaken` |
| Trends empty / chart | `PeriMediUITests/SymptomTrendsTests/testSymptomTrendsNoScores` and `testSymptomTrendsChart` |

`AppRobot.pick` tries an accessibility identifier first, then a visible label. Tests launch `-en`. `addMedication` uses `med.mode.everyday` / `med.mode.cyclic`.

## Proof bar

Do not submit "look, it opens." Proof is a production user path plus an observable result a skeptical reviewer would accept.

- Exercise every reachable entry point, mode, gated variant, and the success, cancel, error, empty, and persistence paths the change can affect.
- Show the trigger and the stable end state in the same evidence (`TEST SUCCEEDED` plus the assertions in that test / the values in the feature file).
- Verify side effects (lane status, strip tokens, Month day values, banner gone), not only the final screen.
- Run doctor first.
- A proof that drives one convenient entry point is incomplete when the map lists others.
- For a broad regression, walk `features/README.md` top to bottom (Full sweep). Driving one feature is not a sweep.

PR-wide UI proof is still `verify: ok` from `bash ios/scripts/verify.sh` (or CI job `ui`). Domain `swift test --package-path ios` alone is not UI proof.

## Evidence

Named location: `.grok/skills/verify-perimedi/evidence/<run-id>/`

Each `drive` writes a subdirectory named after the `--test` path (slashes become dashes), for example `…/evidence/<run-id>/PeriMediUITests-SymptomTrendsTests-testSymptomTrendsNoScores/`. That slot holds `xcodebuild.log` (`TEST SUCCEEDED`), `summary.txt`, `test.txt`, `command.txt`, and `PeriMedi.xcresult`. Later drives on the same run-id must not delete earlier slots. `drives.txt` lists slot names in order. Exercise the real user path (`AppRobot` taps and `typeText`), not `-loadSample`, `-journeyStep`, or test-only setters. Journey tests never pass those flags.

Main-screen PNGs for UX review are `ios/docs/screens/` (written by `ScreenCatalogTests` on a local `verify.sh` unless `SCREEN_CATALOG=0`). Commit those after UI changes. UX reviews the Files changed image diff. Do not paste screenshot galleries into PR comments. `control-perimedi drive` does not rewrite that catalog.

## Cleanup

```bash
.grok/skills/verify-perimedi/scripts/control-perimedi --run-id "$RUN_ID" cleanup
```

Uninstalls `app.perimedi.ios` and the UITest runner on the UDID this run locked, shuts that simulator down only if this run booted it, and deletes the lock and run state. It never kills by process name, never shuts down a simulator it found already Booted, and never deletes evidence. Failed iterations still need this cleanup so locks and leftover installs do not strand the next run.

Do not commit `ios/DerivedData`, `ios/.build`, or secrets.

## Helpers

Driver (executable): `.grok/skills/verify-perimedi/scripts/control-perimedi`

```bash
.grok/skills/verify-perimedi/scripts/control-perimedi --run-id "$RUN_ID" doctor
.grok/skills/verify-perimedi/scripts/control-perimedi --run-id "$RUN_ID" launch
.grok/skills/verify-perimedi/scripts/control-perimedi --run-id "$RUN_ID" doctor
.grok/skills/verify-perimedi/scripts/control-perimedi --run-id "$RUN_ID" \
  drive --test PeriMediUITests/FirstUseJourneyTests/testFirstUseJourney
.grok/skills/verify-perimedi/scripts/control-perimedi --run-id "$RUN_ID" cleanup
```
