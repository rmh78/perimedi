## 1. Pinned today and launch flags

- [x] 1.1 Add `DateKeys.pinnedTodayKey` so `todayKey()` returns the pin when set, otherwise the device clock
- [x] 1.2 Parse `-today=YYYY-MM-DD` (and `-today` plus next argv) in launch flags; set the pin and the selected date; leave production launches unpinned
- [x] 1.3 Reset the pin in domain test teardown if any domain test sets it; `swift test --package-path ios` still passes

## 2. Accessibility identifier contract

- [x] 2.1 Add an `A11yID` catalog with the ids listed in design.md (tabs, pager, Cycle actions, empty/intro, period chip, lane/status, strip day, month day, sheets and fields)
- [x] 2.2 Wire identifiers on Cycle (pager, actions, empty/intro, period chip, lanes, lane status, strip days) without changing VoiceOver labels
- [x] 2.3 Wire identifiers on Month day cells (value includes period / taken / symptom when marked)
- [x] 2.4 Wire identifiers on bottom tabs and on medication, period, and symptom sheet fields, save, delete, and confirm

## 3. UI test target

- [x] 3.1 Extend `generate_pbxproj.py` (and regenerate the project/scheme) so `PeriMediUITests` is an XCTest UI Testing Bundle hosted by PeriMedi and listed in scheme Testables
- [x] 3.2 Add a launch helper that starts the app with `-en -clear -today=2026-03-15` and never passes `-journeyStep` or `-loadSample`
- [x] 3.3 Add a smoke test that waits for `tab.cycle` and `cycle.action.med`; attach a screenshot on failure; `xcodebuild test` on iPhone 17e passes this smoke

## 4. Short feature tests

- [x] 4.1 Superseded: isolated cases were removed; coverage lives in the first-use journey

## 5. First-use journey test

- [x] 5.1 Drive one first-session journey via real controls: empty → period → Estrogen everyday → Progesterone cyclic → mark Estrogen taken → look back through the week and Today → symptom “hot flush” → Month
- [x] 5.2 Assert identifiers/values after each step (two lanes remain, taken persists after Month round-trip, Month cell values include period/taken/symptom); wrap steps in activities; attach a screenshot on failure
- [x] 5.3 Confirm the journey test does not seed store records and `xcodebuild test` on iPhone 17e passes the whole UI suite

## 6. Docs

- [x] 6.1 Document the UI test `xcodebuild test` command and the `-en -clear -today=` launch contract in `AGENTS.md` and `ios/README.md`
- [x] 6.2 Note that `JourneyScript` / `shot-journey.sh` remain visual capture only and are not the interaction proof
