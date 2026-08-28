---
name: verify-perimedi
description: Use this when driving or checking PeriMedi UI from an agent. Maps each user-facing surface to A11yID strings and AppRobot, then says what visible state proves it worked.
---

# Verify PeriMedi

PeriMedi is a native iOS app. Proof is the Simulator on **iPhone 17e**, not markdown and not `iPhone 17`. Identifiers live in `ios/PeriMedi/App/A11yID.swift`. The harness is `ios/PeriMediUITests/AppRobot.swift`. Do not invent IDs.

Read `features/` for the surface you are about to touch. Then drive it.

## Launch

Domain tests (no Simulator):

```bash
source ios/env.sh    # if xcode-select still points at Command Line Tools
swift test --package-path ios
```

UI tests (iPhone 17e, not iPhone 17):

```bash
xcodebuild test -project ios/PeriMedi.xcodeproj -scheme PeriMedi \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -derivedDataPath ios/DerivedData CODE_SIGNING_ALLOWED=NO
```

`AppRobot.launch()` always uses `-en -clear -today=2026-03-15 -uiTesting`. Never pass `-journeyStep` or `-loadSample`. Dose reminders in-process: `-remindIn=4`.

Frozen test dates in `UITestDate`: today `2026-03-15`, yesterday `2026-03-14`, period `2026-03-07`–`2026-03-11`.

## Doctor

- Watch **iPhone 17e** in Simulator (Window → iPhone 17e). iPhone 17 is a different device.
- If `xcode-select -p` is Command Line Tools: `source ios/env.sh` or point it at Xcode.app.
- After any UI change: rebuild, **uninstall**, reinstall, launch on 17e so the Simulator is not a leftover install.

## Drive

1. Open the matching file under `features/`.
2. Get there the way a user would (bottom tabs, Cycle action buttons, sheets).
3. Tap `A11yID` strings through `AppRobot` (`tap`, `waitFor`, `value(of:)`, `exists`).
4. Assert the observable state listed in that file (lane status, empty-meds value, month-day tokens).

`AppRobot.pick` uses **English visible labels** because tests launch with `-en`. IDs themselves are language-independent.

## Evidence

A pass is a green `xcodebuild test` on iPhone 17e, or a screenshot of the 17e Simulator after uninstall/reinstall. Domain `swift test --package-path ios` is not UI proof.

Existing journeys: `FirstUseJourneyTests.testFirstUseJourney` and `testDoseReminderTaken`.

## Cleanup

Do not commit `ios/DerivedData`, `ios/.build`, or secrets. Leave the Simulator app uninstalled after UI work if you changed the binary.

## Product rails

- Bottom nav is Cycle / Month / More. Cycle is home. Edit via sheets, not new full pages.
- No PeriMedi server. Privacy stays on-device (optional iCloud for the same Apple ID).
- No menstrual phase labels (follicular/luteal). Period UI is label + background only.
