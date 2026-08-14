## Context

See `proposal.md` for motivation and `specs/ios-ui-tests/spec.md` / `specs/ios-app/spec.md` for the contract.

Today: domain XCTest under `ios/Tests` (no Simulator), web Vitest for `web/src/lib`, Playwright `web/scripts/shot-journey.mjs` that clicks then only writes PNGs, and iOS `JourneyScript` + `ios/scripts/shot-journey.sh` that **seed** the store via `-journeyStep=N` and screenshot. The app already honors `-en`, `-clear`, `-loadSample`, `-tabMonth`/`-tabMore`, `-sheet*`, and `-journeyStep`. Almost no `accessibilityIdentifier`s. The Xcode scheme has an empty `Testables` list. `ios/scripts/generate_pbxproj.py` emits the app target only.

Marking a dose taken is a tap on the medication lane avatar (`CycleView.medAvatar`); the plot canvas uses `allowsHitTesting(false)`, so tests must not try to tap individual dose cells.

## Goals / Non-Goals

**Goals:**

- A UI test target that `xcodebuild test` can run on the iPhone 17e Simulator next to the existing app build.
- One identifier catalog the app sets and the tests query.
- A pinned-today hook so journey dates are deterministic.
- Wait on element existence, not `sleep`. Screenshots only as `XCTAttachment` on failure.

**Non-Goals:**

- Pixel / snapshot-testing oracles, Maestro, ViewInspector, Playwright `expect()` on the web journey, accessibility-tree fixtures.
- Changing production VoiceOver copy except where an identifier is added beside an existing label.
- Replacing `JourneyScript` / `shot-journey.sh` (they stay as optional visual capture).

## Decisions

### 1. XCUITest is the driver (not Maestro)

**Choice:** Add `PeriMediUITests` as an XCTest UI Testing Bundle in `PeriMedi.xcodeproj`, hosted by the PeriMedi app. Run with:

```bash
source ios/env.sh   # when xcode-select is still Command Line Tools
xcodebuild test \
  -project ios/PeriMedi.xcodeproj \
  -scheme PeriMedi \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -derivedDataPath ios/DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

**Why not Maestro.** Extra CLI, not in Xcode, weaker default CI story. The app already builds unsigned for Simulator; XCUITest is the same toolchain.

**Why not ViewInspector.** Fast, but it does not tap sheets or write SwiftData.

Extend `generate_pbxproj.py` so regenerating the project does not drop the UI test target. Add the target to the scheme’s `Testables`.

### 2. Identifier catalog, not localized strings

**Choice:** One `A11yID` enum (string raw values) in the app. Tests hardcode the same string literals (UI tests cannot import the app module). Convention:

| ID | Control |
| --- | --- |
| `tab.cycle` / `tab.month` / `tab.more` | Bottom destinations |
| `cycle.pager.prev` / `.next` / `.today` / `.label` | Day pager |
| `cycle.action.med` / `.period` / `.symptom` | Cycle header actions |
| `cycle.empty.meds` | Empty-medications card |
| `cycle.intro` | Intro card (empty store) |
| `cycle.chip.period` | Selected-day period chip |
| `cycle.lane.<slug>` | Lane row (avatar + name + status). Slug = lowercased name, spaces → `-` |
| `cycle.lane.<slug>.status` | Taken / not taken / no dose text |
| `cycle.strip.day.<yyyy-mm-dd>` | Cycle-day strip cell; value includes `period` / `symptom` when marked |
| `month.day.<yyyy-mm-dd>` | Month cell; value includes `period` / `taken` / `symptom` when marked |
| `sheet.med` / `sheet.period` / `sheet.symptom` | Sheet roots |
| `med.name` / `med.form` / `med.dose` / `med.mode.everyday` / `med.mode.cyclic` / `med.preset` / `med.start` / `med.save` / `med.delete` | Medication sheet |
| `period.add` / `period.start` / `period.end` / `period.save` | Period sheet |
| `symptom.body` / `symptom.save` | Symptom sheet |
| `confirm.delete` | Delete confirmation |

Localized `.accessibilityLabel` stays the visible/VoiceOver string. Tests query `app.buttons["cycle.action.med"]`, not `"+ Med"`.

Lane slug uses the **name the test types**, so the suite does not need generated medication UUIDs. Dose toggle is the lane control (`cycle.lane.estrogen`), matching the real avatar tap.

### 3. Pin today in `DateKeys`, set from launch args

**Choice:** Add `DateKeys.pinnedTodayKey: String?` (domain). `todayKey()` returns the pin when set, otherwise `toDateKey(Date())`. `RootView.applyLaunchFlags` sets it from `-today=YYYY-MM-DD` (and accepts `-today` + next argv). Also set `AppModel.selectedDate` to that key. Domain unit tests leave the pin nil (or reset in `tearDown` if a test sets it).

**Why not inject a Clock protocol everywhere.** `todayKey()` is already the single clock read. A protocol would touch every call site for no production benefit.

**Why not keep using the device clock.** The journey is `today-8` / `today-4`. Element values and Month cell ids would change every midnight.

Pinned date for the suite: **`2026-03-15`** (a Sunday). Period in the journey is `2026-03-07` … `2026-03-11`.

Every UI test launches with:

```
-en -clear -today=2026-03-15
```

Do **not** pass `-journeyStep` or `-loadSample` in this suite.

### 4. One first-use journey test only

**Choice:**

- `FirstUseJourneyTests` — a single method that walks a first session so state carries: empty home → log last period → everyday estrogen → cyclic progesterone → mark today’s estrogen taken → page back through the week and Today → symptom “hot flush” → Month agrees and Cycle still shows both lanes taken. Assert after each beat; `XCTContext.runActivity` per step; `add(XCTAttachment(screenshot:))` in `tearDown` on failure.
- No separate smoke or isolated feature cases. A broken control fails this journey.

Helpers live in the UI test target (`AppRobot`): launch, wait, tap id, type into `med.name`, dismiss keyboard, wait for sheet to vanish.

Use `waitForExistence(timeout:)` / `XCTNSPredicateExpectation`. No fixed `sleep`.

### 5. Screenshots are attachments, not comparators

**Choice:** On failure, attach `XCUIScreen.main.screenshot()`. Never `XCTAssertEqual` PNG bytes. `shot-journey.sh` remains for humans who want PNG pairs.

### 6. Local-only store in tests

**Choice:** Keep the existing CloudKit entitlement gate (unsigned Simulator already local-only). `-clear` must wipe SwiftData so a previous test’s data cannot leak if a process is reused. Prefer `XCUIApplication` launch per test (default) over assuming process isolation.

## Risks / Trade-offs

- **[SwiftUI sheets / first-launch settle]** → Wait for `tab.cycle` and `cycle.action.med` after launch; wait for `sheet.*` after opening; do not sleep 4–6 seconds like `shot-journey.sh`.
- **[Plot not hittable]** → Toggle taken via `cycle.lane.<slug>` (avatar), not a cell in the scroll plot.
- **[Date pin leaks into domain tests]** → Reset `pinnedTodayKey` in domain `tearDown` if any test sets it; production launch never passes `-today`.
- **[pbxproj generator drops the UI test target]** → Generator must emit the UI test target, its sources, and the scheme `Testables` entry.
- **[German default on this Mac]** → Suite always passes `-en`. A single extra case may launch without `-en` only to assert identifiers still resolve.
- **[Slow Simulator tests on 8 GB]** → Keep the suite to one first-use journey. Do not screenshot every passing step.

## Migration Plan

1. Identifier enum + wire IDs + `DateKeys.pinnedTodayKey` + `-today=` (app still behaves the same for normal launches).
2. Generate UI test target; empty test that launches and finds `tab.cycle`.
3. Short tests, then the journey.
4. Document the `xcodebuild test` line in `AGENTS.md` / `ios/README.md`.
5. Rollback: delete the UI test target and IDs; unpin `DateKeys`. No data migration.

## Open Questions

None that change the specs or task shape. Exact helper type names (`AppRobot` vs `XCUIApplication` extensions) can be chosen at apply time.
