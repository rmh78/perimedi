## Why

iOS journey “proof” today is seeded store snapshots plus a human comparing PNGs. That does not fail when a tap is broken, and it cannot tell a taken dose that the user marked from one that `JourneyScript` wrote in. Domain tests already cover schedule math. What is missing is an instrumented interaction suite that starts empty, drives the real controls, and asserts UI elements and resulting state.

## What Changes

- Add a stable, language-independent **accessibility identifier contract** on Cycle, Month, More, sheets, lanes, and dose cells so automation (and assistive tech) can find controls without depending on English or German chrome.
- Add a **test launch contract**: pin English, clear the store, and freeze “today” to a supplied calendar date so assertions are not date-relative time bombs.
- Add an **XCUITest** target that proves the empty-to-tracking journey by tapping: empty Cycle → add period → add mixed meds → edit/delete → pager ±1 → mark taken → add symptom → Month agrees. Assert identifiers and values at each step. Attach a screenshot when a step fails. Do **not** use pixel comparison as the pass/fail oracle.
- Add a few **short feature tests** (add period, add everyday med, toggle taken, Month reflects Cycle date) so a single failure is cheaper to localize than only a 12-step journey.
- Keep `JourneyScript` / `shot-journey.sh` for optional visual review. Interaction tests MUST start from a cleared store and tap; they MUST NOT seed the journey via `-journeyStep`.
- **Not in this change:** Maestro, ViewInspector, Playwright `expect()` conversion of the web journey, accessibility-tree fixtures, cropped pixel snapshots, CI cloud runners, or App Store TestFlight.

## Capabilities

### New Capabilities

- `ios-ui-tests`: Instrumented iOS interaction verification — identifier contract, test launch flags (language, empty store, frozen today), XCUITest journey and short feature tests that assert UI elements and resulting state. Screenshots are failure evidence, not the gate.

### Modified Capabilities

- `ios-app`: The empty-to-tracking journey remains required product behavior. Automated UI-element verification from an empty store becomes the proof that the user can actually perform those steps. Reviewer screenshot pairs stay allowed for visual-family checks; they are no longer the only (or primary) way to prove the journey.

## Impact

- iOS app views gain `accessibilityIdentifier`s. Existing VoiceOver labels stay; identifiers are the automation handle.
- New launch arguments (`-today=YYYY-MM-DD` at minimum; reuse `-en` and `-clear`). The generated `pbxproj` / scheme gain a UI test target.
- New `ios/PeriMediUITests` (name may vary) run on the iPhone 17e Simulator via `xcodebuild test`. Domain `swift test --package-path ios` is unchanged.
- No PeriMedi server, analytics, or web UI changes. Web `shot:journey` remains a visual capture script, not the iOS gate.
