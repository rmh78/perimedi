# PeriMedi — agent notes

Perimenopause medication companion: track doses, periods, and symptoms.

The **product is a native iOS app** (`ios/`). Data lives in on-device SwiftData, with optional Apple iCloud for the same Apple ID. There is no PeriMedi server, product account, or website.

## Stack

SwiftUI, SwiftData, CloudKit (fallback to local-only), `PeriMediDomain` Swift package.

## Project layout

```
ios/                 # Xcode app + PeriMediDomain package
  PeriMedi/          # SwiftUI app
    Features/Cycle   # home + med/period/symptom sheets
    Features/Month
    Features/More
    Features/Sheets  # DialogChrome only
  PeriMediUITests/   # first-use XCUITest journey (empty → tracking)
  Sources/           # domain (cycle, schedule, therapy, backup, seed, symptoms)
  Tests/             # XCTest for domain
  docs/              # iCloud device-switch notes
openspec/            # product specs
```

Archived OpenSpec changes under `openspec/changes/archive/` may mention an old web companion; they are historical. Current product contract is `openspec/specs/` plus this file.

## Product rules

- **Cycle / Month / More** via bottom nav. Cycle is the default home. Edit meds/schedules/symptoms via sheets, not extra full pages.
- **Not medical advice** — sample data and UI are a personal demo, not clinical guidance.
- Keep privacy local: never introduce a PeriMedi server or analytics without explicit user request. Apple iCloud (user’s Apple ID) is the allowed sync path.
- Prefer clear, short UI copy (+ Med, Cycle settings, + Symptom, Taken / Not taken).

## Domain concepts

- **Medication** — name, form, default dose, optional color
- **Schedule** — times; exclusive mode: every day, specific weekdays, or cyclic (apply N / pause M or week slots). Saved without menstrual-alignment UI (`cycleRule: none` in the editor).
- **Period** — logged bleeds; day 1 of a cycle is the first period day
- **SymptomScore** — catalog id (`hot_flash`, …), date, severity 1–4, optional note, loggedAt. Untouched ids are missing (none), not stored as 0.
- **Remark** — optional day note (and older backup note rows)
- **DoseLog** — taken / pending (open) per planned dose

Schedule expansion: `ios/Sources/PeriMediDomain`.

Domain owns schedule/cycle/therapy expansion (`ScheduleLogic` / `CycleLogic` / `TherapyCycleLogic` / `DoseRangeLogic`). The UI calls those; it must not reimplement the math. `Store` is the only dose-log writer (`setDoseStatus`). CI `ids` runs `python3 ios/scripts/check-domain-boundary.py`. Protect main is still `ids`, `domain`, and `ui`.

## Commands

The doctor is one script. Run it after feature work instead of picking among the pieces:

```bash
bash ios/scripts/verify.sh
```

It sources `ios/env.sh`, checks feature-map IDs, checks feature layout, checks domain boundary, fails UI-test coverage if a feature-map surface is uncovered, runs domain tests, uninstalls leftover PeriMedi, runs `xcodebuild test`, then uninstalls again on success. It prefers **iPhone 17e**, then **iPhone 17** locally. Override with `SIM_DEVICE`, `SIM_OS` (e.g. `26.5`), or `SIM_UDID`. GitHub Actions pins `macos-26` + Xcode 26.6 and requires iPhone 17e on iOS 26.5 (no fallback). It needs macOS + Xcode; anywhere else it still runs the ID, layout, domain-boundary, and coverage checks, then exits. Before it boots the Simulator, it turns Connect Hardware Keyboard off for that UDID so `typeText` hits the software keyboard (the phone path).

CI runs only on `pull_request` (not on push to main). A new commit on a PR cancels the previous `ci` run for that PR. Every PR runs `ids` on Ubuntu (`python3 ios/scripts/check-feature-map.py`, `python3 ios/scripts/check-feature-layout.py`, `python3 ios/scripts/check-domain-boundary.py`, then `python3 ios/scripts/check-ui-coverage.py --fail-uncovered`), `domain` on macOS 26 with Xcode 26.6 (`swift test --package-path ios`), and `ui` on the same pin (`bash ios/scripts/verify.sh`). A green `ui` job is UI proof. Protect main requires `ids`, `domain`, and `ui`. Coverage is a failing check inside `ids` (and the local doctor); do not add a separate Protect main name. On GitHub the doctor skips the Python rails and domain tests (`ids` / `domain` already ran them). A failed `ui` job uploads `ios/DerivedData/PeriMedi.xcresult`.

Pieces, if you need one step:

```bash
# Domain tests (no Simulator)
source ios/env.sh    # if xcode-select still points at Command Line Tools
swift test --package-path ios

# iOS Simulator build
xcodebuild -project ios/PeriMedi.xcodeproj -scheme PeriMedi \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -derivedDataPath ios/DerivedData CODE_SIGNING_ALLOWED=NO build

# iOS UI tests (local default: iPhone 17e)
xcodebuild test -project ios/PeriMedi.xcodeproj -scheme PeriMedi \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -derivedDataPath ios/DerivedData CODE_SIGNING_ALLOWED=NO

# Feature map ID coverage (fails CI)
python3 ios/scripts/check-feature-map.py

# Feature layout (fails CI)
python3 ios/scripts/check-feature-layout.py

# Domain owns math; persistence writes logs (fails CI)
python3 ios/scripts/check-domain-boundary.py

# Feature map vs UITest coverage (fails CI / doctor with --fail-uncovered)
python3 ios/scripts/check-ui-coverage.py --fail-uncovered
```

UI tests are `FirstUseJourneyTests` (`testFirstUseJourney`, `testMonthPager`, `testMoreRemindersControls`) plus a dose-reminder journey (`testDoseReminderTaken`). They launch with `-en -clear -today=2026-03-15` and tap real controls. They type into fields the way a user does (`typeText`). Do not paste, use the clipboard menu, or test-only setters; that makes the journey synthetic. `clearAndType` taps the field, waits until the software keyboard exists, types, then asserts the exact value. They never pass `-journeyStep` or `-loadSample`. Watch **iPhone 17e** in Simulator when that device exists (Window → iPhone 17e).

`JourneyScript` / `ios/scripts/shot-journey.sh` remain optional visual capture (seeded store snapshots). They are not the interaction proof.

If `xcode-select -p` is Command Line Tools, either `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` or `source ios/env.sh` (`DEVELOPER_DIR`). The doctor sources `ios/env.sh` for you.

Simulator signing does not require a paid team. Add an Apple ID in Xcode → Accounts later for device / production CloudKit. See `ios/docs/icloud-device-switch.md`.

## Conventions

- **i18n:** iOS chrome via `LocaleController` + `L10n` (en/de) and `Localizable.xcstrings`. Language control lives in More; preference is `AppStorage` (`perimedi.locale`). Default German if device preferred languages include German. User-entered text is never translated.
- **Layout review:** run on a narrow iPhone Simulator (iPhone 17e) and screenshot.
- iOS sheets: `MedicationSheet`, `PeriodSheet`, `SymptomSheet` presented over Cycle.
- New user-facing Swift goes under `Features/Cycle`, `Features/Month`, or `Features/More`. Do not grow `CycleView.swift`, `L10n.swift`, or `DialogChrome.swift` with new screens. New sheets colocate with the feature they belong to. `Features/Sheets/` is shared chrome only (`DialogChrome.swift`).
- Sample data: `SampleData.payload()` via More → Backup.
- JSON backup is `ExportPayload` version 1.
- Do not commit `ios/DerivedData`, `ios/.build`, or secrets. No `.env` required.

## When changing features

1. Prefer extending existing sheets over new full pages.
2. Keep med lane labels and dose tracks row-aligned on Cycle.
3. Period UI: label + background only (no duplicate red bar).
4. No menstrual “phase” labels (follicular/luteal etc.).
5. After structural or UI changes: `bash ios/scripts/verify.sh`.
6. If you skip the doctor and launch by hand: rebuild, **uninstall**, reinstall, and launch on **iPhone 17e** so the Simulator is not showing a leftover install.
7. Keep the feature map current in the same commit (see Feature map below).
8. New Swift files go next to the feature (`Features/Cycle`, `Features/Month`, or `Features/More`), not in `CycleView.swift` / `L10n.swift` / `DialogChrome.swift` / `Features/Sheets`.

## Feature map (for agents)

When driving or checking a screen, read `.grok/skills/verify-perimedi/` first. `features/` maps each surface to real `A11yID` strings and `AppRobot`. Do not invent identifiers.

Soft: same commit as the feature, like OpenSpec. A new user-facing surface gets a new file under `.grok/skills/verify-perimedi/features/`. A change to how a user gets there, what visible state proves it worked, or a gotcha updates that file even when no `A11yID` was added. CI cannot see those.

Hard: `python3 ios/scripts/check-feature-map.py` must pass (the doctor runs it). CI job `ids` runs it on every PR. `python3 ios/scripts/check-feature-layout.py` must also pass; `ids` runs it too. `python3 ios/scripts/check-domain-boundary.py` must pass; `ids` runs it too. CI job `domain` runs `swift test --package-path ios` on macOS. CI job `ui` runs the doctor (Simulator XCUITest). Protect main requires `ids`, `domain`, and `ui`.

Coverage is a failing check inside `ids` (and the doctor): `python3 ios/scripts/check-ui-coverage.py --fail-uncovered` fails when a feature-map surface with distinctive IDs is never driven by UI tests. Waiting for `tab.more` is not coverage. More and backup journeys exist (`testMoreRemindersControls`). Do not add coverage as a separate required check. Protect main stays `ids`, `domain`, and `ui`.

## OpenSpec

Product behavior is specified under `openspec/specs/<capability>/spec.md`.

**Workflow**

1. For behavior changes: update the relevant main specs, **or** open an OpenSpec **change** with delta specs and archive/sync when the change completes.
2. Spec shape: `## Purpose`, `## Requirements`, `### Requirement: …` (SHALL/MUST), and at least one `#### Scenario:` with WHEN/THEN. Describe observable behavior only — not component or file names.
3. Ship OpenSpec updates **in the same commit** as the feature/fix when behavior changes.
4. After editing specs: `openspec validate --specs --strict` when practical.

Do not invent requirements unrelated to the product or the change.
