---
name: verify-perimedi
description: Use this when driving or checking PeriMedi UI from an agent. Maps each user-facing surface to A11yID strings and AppRobot, then says what visible state proves it worked.
---

# Verify PeriMedi

PeriMedi is a native iOS app. Proof is XCUITest on an iPhone Simulator (local default **iPhone 17e**), not markdown. Identifiers live in `ios/PeriMedi/App/A11yID.swift`. The harness is `ios/PeriMediUITests/AppRobot.swift`. Do not invent IDs.

Read `features/` for the surface you are about to touch. Then drive it.

## Launch

The doctor is one command:

```bash
bash ios/scripts/verify.sh
```

That sources `ios/env.sh`, checks feature-map IDs, checks feature layout, checks domain boundary, fails UI-test coverage if a feature-map surface is uncovered, runs domain tests, uninstalls leftover PeriMedi, runs UI tests, and uninstalls again on success. It prefers iPhone 17e, then iPhone 17. Override with `SIM_DEVICE` or `SIM_UDID`.

Pieces, if you need one step:

Domain tests (no Simulator):

```bash
source ios/env.sh    # if xcode-select still points at Command Line Tools
swift test --package-path ios
```

UI tests (local default: iPhone 17e):

```bash
xcodebuild test -project ios/PeriMedi.xcodeproj -scheme PeriMedi \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -derivedDataPath ios/DerivedData CODE_SIGNING_ALLOWED=NO
```

`AppRobot.launch()` always uses `-en -clear -today=2026-03-15 -uiTesting`. Never pass `-journeyStep` or `-loadSample`. Dose reminders in-process: `-remindIn=4`.

Frozen test dates in `UITestDate`: today `2026-03-15`, yesterday `2026-03-14`, period `2026-03-07`–`2026-03-11`.

## Doctor

Run `bash ios/scripts/verify.sh`. That is the doctor. Do not assemble the steps by hand unless you need a single piece.

- Watch **iPhone 17e** in Simulator when that device exists (Window → iPhone 17e).
- The script sources `ios/env.sh` (needed when `xcode-select -p` is Command Line Tools).
- It uninstalls leftover `app.perimedi.ios` before UI tests, and again after a pass. Failed tests leave the app so you can inspect.
- `python3 ios/scripts/check-feature-map.py` must pass. It fails if an `A11yID` is not named in backticks under `features/` . Update the matching feature file in the same commit as the ID or surface change.
- `python3 ios/scripts/check-feature-layout.py` must pass. Feature sheets live under `Features/Cycle`, `Features/Month`, or `Features/More`. `DialogChrome` stays in `Features/Sheets/`.
- `python3 ios/scripts/check-domain-boundary.py` must pass. Domain owns schedule/cycle/therapy expansion; `Store.setDoseStatus` is the only dose-log writer.
- `python3 ios/scripts/check-ui-coverage.py --fail-uncovered` must pass (the doctor and CI `ids` job pass the flag). It fails when a surface with distinctive IDs is never driven by UI tests. Waiting for `tab.more` is not coverage. More and backup journeys exist (`testMoreRemindersControls`). A bare local run without the flag stays advisory.

## Drive

1. Open the matching file under `features/`.
2. Get there the way a user would (bottom tabs, Cycle action buttons, sheets).
3. Tap `A11yID` strings through `AppRobot` (`tap`, `waitFor`, `value(of:)`, `exists`).
4. Type into fields the way a user does (`clearAndType` / `typeText`). Do not paste, use the clipboard menu, or test-only setters.
5. Assert the observable state listed in that file (lane status, empty-meds value, month-day tokens).

`AppRobot.pick` tries the option as an accessibility identifier first, then falls back to a visible label. Tests launch with `-en`. `addMedication` uses `med.mode.everyday` / `med.mode.cyclic`. IDs themselves are language-independent.

## Evidence

A pass is `verify: ok` from `bash ios/scripts/verify.sh` on a Mac with Xcode. Domain `swift test --package-path ios` alone is not UI proof. CI job `ui` is the same proof on GitHub (17e if the image has it, else iPhone 17). A screenshot of the Simulator after uninstall/reinstall is extra, not a substitute for the doctor.

Existing journeys: `FirstUseJourneyTests.testFirstUseJourney`, `testMonthPager`, `testMoreRemindersControls`, and `testDoseReminderTaken`.

## Cleanup

Do not commit `ios/DerivedData`, `ios/.build`, or secrets. The doctor uninstalls the Simulator app after a pass. If you changed the binary without the doctor, uninstall leftover PeriMedi yourself.

## Product rails

- Bottom nav is Cycle / Month / More. Cycle is home. Edit via sheets, not new full pages.
- No PeriMedi server. Privacy stays on-device (optional iCloud for the same Apple ID).
- No menstrual phase labels (follicular/luteal). Period UI is label + background only.
