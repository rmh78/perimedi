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
    Features/Trends  # cycle chart of count and intensity
    Features/Month
    Features/More
    Features/Sheets  # DialogChrome only
  PeriMediUITests/   # first-use XCUITest journey (empty → tracking)
  PeriMediTests/     # app unit tests (symptom-day marks, Store export)
  Sources/           # domain (cycle, schedule, therapy, backup, seed, symptoms)
  Tests/             # XCTest for domain
  docs/              # iCloud device-switch notes
openspec/            # product specs
```

Archived OpenSpec changes under `openspec/changes/archive/` may mention an old web companion; they are historical. Current product contract is `openspec/specs/` plus this file.

## Product rules

- **Cycle / Month / Trends / More** via bottom nav. Cycle is the default home. Edit meds/schedules/symptoms via sheets, not extra full pages.
- **Not medical advice** — sample data and UI are a personal companion, not clinical guidance. Sample payloads stay fictional.
- Keep privacy local: never introduce a PeriMedi server or analytics without explicit user request. Apple iCloud (user’s Apple ID) is the allowed sync path.
- Prefer clear, short UI copy (+ Med, Cycle settings, + Symptom, Taken / Not taken).

## Domain concepts

- **Medication** — name, form, default dose, optional color
- **Schedule** — times; exclusive mode: every day, specific weekdays, or cyclic (apply N / pause M or week slots). Saved without menstrual-alignment UI (`cycleRule: none` in the editor).
- **Period** — logged bleeds; day 1 of a cycle is the first period day
- **SymptomScore** — catalog id (`hot_flash`, …) or a custom id (`c.` plus a UUID), date, severity 1–4, optional note, loggedAt. Untouched ids are missing (none), not stored as 0.
- **Custom symptom** — a stored name and sort order under the eleven defaults. The name is the user’s text. Rename keeps the id. Delete removes that symptom and its scores. The list round-trips on the version-1 backup. Import drops a custom score whose id is no longer in that list. Rows with the same name, ignoring case, fold into one after sync; the earlier order wins and scores move to it.
- **Remark** — optional day note (and older backup note rows)
- **DoseLog** — taken / pending (open) per planned dose
- **MedicationChange** — stored dose/schedule change events (name snapshot, previous/new value, effective date). Survive medication delete. Cleared on wipe/import, not on delete-med.

Schedule expansion: `ios/Sources/PeriMediDomain`.

Domain owns schedule/cycle/therapy expansion (`ScheduleLogic` / `CycleLogic` / `TherapyCycleLogic` / `DoseRangeLogic`). The UI calls those; it must not reimplement the math. `Store` is the only dose-log writer (`setDoseStatus`). CI `ids` runs `python3 ios/scripts/check-domain-boundary.py`. Protect main requires `ids`, `openspec`, `domain`, and `ui`.

## Commands

The product UI proof is one command. Run it after feature work instead of picking among the pieces:

```bash
.grok/skills/verify-perimedi/scripts/control-perimedi verify
```

It sources `ios/env.sh`, checks feature-map IDs, checks feature layout, checks L10n layout, checks domain boundary, checks OpenSpec sync, checks the App Store listing, fails UI-test coverage if a feature-map surface is uncovered, runs domain tests, starts `xcodebuild build-for-testing` for `generic/platform=iOS Simulator` while it shuts the simulator down, turns the hardware keyboard off and boots, then runs `xcodebuild test-without-building` on the booted iPhone 17e with `-resultBundlePath`. Every `xcodebuild` call from this driver, including `build-for-testing` and `drive`, passes `-collect-test-diagnostics never`. While that command runs, the driver kills a stray `simctl diagnose` for the simulator. It does not fall back to a second full `xcodebuild test`. If that generic product lacks `group.app.perimedi.ios` on the app and the widget, it rebuilds `build-for-testing` for the booted UDID and does not install the unsigned-group product. It checks the screen catalog files exist (no pixel compare), then uninstalls again on success. Locally that test run writes the sixteen English files in `ios/docs/screens/` unless `SCREEN_CATALOG=0`. On GitHub it skips `ScreenCatalogTests` (committed PNGs; `ids` already checks they exist). The English widget journey runs on GitHub and rewrites its two pictures on every run. Device is **iPhone 17e** only. Do not fall back to another iPhone. Unset `SIM_DEVICE` is fine. `SIM_DEVICE` set to anything other than `iPhone 17e` fails. `SIM_OS` still selects the runtime (e.g. `27.0`). `SIM_UDID` is allowed only when that simulator is named iPhone 17e. The `ui` job runs on the `xcode-27` image with Xcode 27.0 and iPhone 17e on iOS 27.0. The `domain` job stays on `macos-26` with Xcode 26.6. It needs macOS + Xcode; anywhere else it still runs the ID, layout, domain-boundary, OpenSpec-sync, and coverage checks, then exits. Before it boots the Simulator, it turns Connect Hardware Keyboard off for that UDID so `typeText` hits the software keyboard (the phone path). On GitHub CI, verify skips the status-bar override and does not uninstall leftover PeriMedi before the tests. It still uninstalls after a successful run. Locally, an occupied 17e whose lock is not this suite run is refused.

It also runs `python3 ios/scripts/check-one-way-door.py --base origin/main`. That check warns and exits 0.

CI runs on every pull request. CI also runs on main at 04:17 UTC, and when someone starts it with `gh workflow run ci.yml --ref main`. CI does not run on push. A new commit on a pull request cancels the previous ci run for that pull request. A run on main does not cancel a running main run. Every PR runs `ids` on Ubuntu (`python3 ios/scripts/check-feature-map.py`, `python3 ios/scripts/check-feature-layout.py`, `python3 ios/scripts/check-l10n-layout.py`, `python3 ios/scripts/check-domain-boundary.py`, `python3 docs/app-store/check-listing.py`, `python3 ios/scripts/check-ui-coverage.py --fail-uncovered`, `python3 ios/scripts/check-screen-catalog.py`, `python3 ios/scripts/check-one-way-door.py` (notice only, `continue-on-error`, does not fail `ids`), `python3 ios/scripts/check-agent-rails.py`, `python3 ios/scripts/check-ui-test-names.py`, `python3 ios/scripts/check-pr-attachments.py`, `python3 ios/scripts/test_check_one_way_door.py`, `python3 ios/scripts/test_check_agent_rails.py`, then `python3 .github/scripts/test_main_is_red.py`), `openspec` on Ubuntu (`python3 ios/scripts/check-openspec-sync.py`), `domain` on macOS 26 with Xcode 26.6 (`swift test --package-path ios`), and `ui` on the `xcode-27` image with Xcode 27.0 and iPhone 17e on iOS 27.0 (`.grok/skills/verify-perimedi/scripts/control-perimedi verify`). A green `ui` job is UI proof. Protect main requires `ids`, `openspec`, `domain`, and `ui`. The live ruleset already includes openspec. `main-status` is not a required check. Do not add it to Protect main. GitHub turns scheduled workflows off after 60 days without activity in a public repository. Turn that schedule back on with `gh workflow enable ci.yml`. CI Manager watches the "main is red" issue with the `main-red` label. An unlabeled issue with the same title is left alone and the bot opens its own labeled one. A red main run opens or updates the labeled issue. A plain green main run closes it. If creating the label fails and the label is not already there, the new issue is opened without the label and later runs leave it alone. `gh workflow run ci.yml --ref main -f force_red=true` fails `ids` before checkout, skips `openspec`, `domain`, and `ui`, and opens or updates the issue with the line `Drill: force_red`. That drill does not close the issue. The next plain `gh workflow run ci.yml --ref main` closes it when `ids`, `openspec`, `domain`, and `ui` are green. Start main proof runs one at a time. A newer waiting run cancels an older waiting run. A scheduled run can start hours after the cron time. Coverage stays inside `ids`; OpenSpec sync is the `openspec` job. On GitHub, `verify` skips the Python rails and domain tests (`ids` / `openspec` / `domain` already ran them). A failed `ui` job uploads `ios/DerivedData/PeriMedi.xcresult`.

Pieces, if you need one step:

```bash
# Domain tests (no Simulator)
source ios/env.sh    # if xcode-select still points at Command Line Tools
swift test --package-path ios

# iOS Simulator build
xcodebuild -project ios/PeriMedi.xcodeproj -scheme PeriMedi \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -derivedDataPath ios/DerivedData CODE_SIGNING_ALLOWED=NO build

# iOS UI tests, including the English widget journey (local default: iPhone 17e).
# Do not pass CODE_SIGNING_ALLOWED=NO. That drops the App Group and the widget stays empty.
xcodebuild test -project ios/PeriMedi.xcodeproj -scheme PeriMedi \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -derivedDataPath ios/DerivedData \
  DEVELOPMENT_TEAM=7H4A6PWSPS CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_ENTITLEMENTS=PeriMediDoseWidget/PeriMediDoseWidget.entitlements \
  -allowProvisioningUpdates

# Feature map ID coverage (fails CI)
python3 ios/scripts/check-feature-map.py

# Feature layout (fails CI)
python3 ios/scripts/check-feature-layout.py

# Trends and Visit keys stay out of L10n.swift; en/de tables match (fails CI)
python3 ios/scripts/check-l10n-layout.py

# Domain owns math; persistence writes logs (fails CI)
python3 ios/scripts/check-domain-boundary.py

# OpenSpec change deltas in main specs (fails CI)
python3 ios/scripts/check-openspec-sync.py

# Feature map vs UITest coverage (fails CI / verify with --fail-uncovered)
python3 ios/scripts/check-ui-coverage.py --fail-uncovered

# Screen catalog files exist (no pixel compare)
python3 ios/scripts/check-screen-catalog.py

# Wired scripts are named in Agents.md (fails CI)
python3 ios/scripts/check-agent-rails.py

# UI test methods are named in Agents.md or features (fails CI)
python3 ios/scripts/check-ui-test-names.py

# PR text does not link user-attachment hosts (fails CI)
python3 ios/scripts/check-pr-attachments.py

# One-way door diff. Warns only.
python3 ios/scripts/check-one-way-door.py --base origin/main

# App Store listing limits. Run before any listing edit. Fails CI.
python3 docs/app-store/check-listing.py

# Regenerate the 6.9" store screenshots on iPhone 18 Pro Max.
bash docs/app-store/capture-store-shots.sh

# Regenerate the 6.1" and 6.3" store screenshots on iPhone 17 Pro.
bash docs/app-store/capture-store-shots.sh 6.3

# ids job only. verify does not run this.
python3 .github/scripts/test_main_is_red.py
```

The required UI suite is two English XCTest methods. `testEnglishAppJourney` is one process for empty home, empty Trends, period edit and delete, the period logged again, meds, the in-app reminder (including snooze), Month, and More. On More it taps German until the More tab reads Mehr, then taps English until it reads More. It then uses a `.trendsChart` launch for the chart and the custom symptom, then `.trendsNoScores`. `testEnglishWidgetJourney` is one process: medium widget, then small, without a new app launch. Both run on GitHub. The app journey pins today to `2026-03-15`. The widget pins today to the device date. They tap real controls. `clearAndType` waits for the software keyboard, sends the whole string in one `typeText` (or one delete string, then one retype), refocuses once if the value is still wrong, and asserts the exact value. Do not paste, type one character per `typeText`, use the clipboard menu, or test-only setters. Journey tests never pass `-journeyStep` or `-loadSample`. `ScreenCatalogTests.testWriteScreenCatalog` may pass `-loadSample` and writes the sixteen English names in a few launches (not one launch per PNG). It may switch to German only to write `sheet-symptom-pill-de.png`. `StoreScreenshotTests.testWriteStoreScreenshots` runs only when `STORE_SHOTS=1`. It is not part of `verify`. The 6.9" App Store Connect slot is `docs/app-store/screenshots/en/` and `docs/app-store/screenshots/de/` at 1320×2868 or 1290×2796, captured on iPhone 18 Pro Max. The 6.1" and 6.3" slot is `docs/app-store/screenshots-6.3/en/` and `docs/app-store/screenshots-6.3/de/` at 1206×2622, captured on iPhone 17 Pro. Both use the same six frames, the same order, and today pinned to 2026-03-15. Upload order is the filename numbers. Before any listing edit, run `python3 docs/app-store/check-listing.py`. Regenerate the 6.9" set with `bash docs/app-store/capture-store-shots.sh`. Regenerate the 6.1" and 6.3" set with `bash docs/app-store/capture-store-shots.sh 6.3`. CI skips rewriting those catalog PNGs; the `ids` job still fails if a committed file is missing. The widget journey rewrites `widget-medium-before-en.png` and `widget-medium-after-en.png` on every run. Local `verify` writes the catalog unless `SCREEN_CATALOG=0`. Watch **iPhone 17e** in Simulator when that device exists (Window → iPhone 17e).

Main-screen pictures for UX are `ios/docs/screens/` (written by `ScreenCatalogTests` on a local `verify`). `JourneyScript` / `ios/scripts/shot-journey.sh` remain optional extra capture. They are not the interaction proof.

If `xcode-select -p` is Command Line Tools, either `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` or `source ios/env.sh` (`DEVELOPER_DIR`). `control-perimedi` sources `ios/env.sh` for you.

Simulator signing does not require a paid team. Add an Apple ID in Xcode → Accounts later for device / production CloudKit. See `ios/docs/icloud-device-switch.md`.

## Conventions

- **i18n:** iOS chrome via `LocaleController` + `L10n` (en/de) and `Localizable.xcstrings`. Language control lives in More; preference is `AppStorage` (`perimedi.locale`). Default German if device preferred languages include German. User-entered text is never translated.
- **Layout review:** UI tests write `ios/docs/screens/`. Commit those PNGs. UX reviews the Files changed image diff. Do not paste screenshot galleries into PR comments.
- iOS sheets: `MedicationSheet`, `PeriodSheet`, `SymptomSheet` presented over Cycle.
- New user-facing Swift goes under `Features/Cycle`, `Features/Trends`, `Features/Month`, or `Features/More`. Do not grow `CycleView.swift`, `L10n.swift`, or `DialogChrome.swift` with new screens. New sheets colocate with the feature they belong to. `Features/Sheets/` is shared chrome only (`DialogChrome.swift`).
- Sample data: `SampleData.payload()` via More → Backup.
- JSON backup is `ExportPayload` version 1.
- Do not commit `ios/DerivedData`, `ios/.build`, or secrets. No `.env` required.

## One-way doors

Content rules live in `ios/docs/one-way-doors.md`. The checker is `ios/scripts/check-one-way-door.py`. On a pull request, `ids` runs that script and prints a GitHub notice. The step sets `continue-on-error`. A git or Python failure prints a warning and exits 0. The notice does not fail `ids`. Local verify runs the same script with `--base origin/main`. The script exits 0, so verify keeps going.

Every new ExportPayload key gets an import test for a v1 file that omits that key, following `testOldBackupWithoutCustomSymptomsDecodesEmpty`. The checker has unit tests in `ios/scripts/test_check_one_way_door.py`. `ids` runs that file, and a failure there fails `ids`.

## When changing features

1. Prefer extending existing sheets over new full pages.
2. Keep med lane labels and dose tracks row-aligned on Cycle.
3. Period UI: label + background only (no duplicate red bar).
4. No menstrual “phase” labels (follicular/luteal etc.).
5. After structural or UI changes: `.grok/skills/verify-perimedi/scripts/control-perimedi verify`.
6. If you skip `verify` and launch by hand: rebuild, **uninstall**, reinstall, and launch on **iPhone 17e** so the Simulator is not showing a leftover install.
7. Keep the feature map current in the same commit (see Feature map below).
8. New Swift files go next to the feature (`Features/Cycle`, `Features/Trends`, `Features/Month`, or `Features/More`), not in `CycleView.swift` / `L10n.swift` / `DialogChrome.swift` / `Features/Sheets`.

## Feature map (for agents)

When driving or checking a screen, read `.grok/skills/verify-perimedi/` first. `features/` maps each surface to real `A11yID` strings and `AppRobot`. Do not invent identifiers.

Soft: same commit as the feature, like OpenSpec. A new user-facing surface gets a new file under `.grok/skills/verify-perimedi/features/`. A change to how a user gets there, what visible state proves it worked, or a gotcha updates that file even when no `A11yID` was added. CI cannot see those.

Hard: `python3 ios/scripts/check-feature-map.py` must pass (`control-perimedi verify` and `doctor` run it). CI job `ids` runs it on every PR. `python3 ios/scripts/check-feature-layout.py` must also pass; `ids` runs it too. `python3 ios/scripts/check-l10n-layout.py` must pass; `ids` runs it too. `python3 ios/scripts/check-domain-boundary.py` must pass; `ids` runs it too. CI job `openspec` runs `python3 ios/scripts/check-openspec-sync.py`. CI job `domain` runs `swift test --package-path ios` on macOS. CI job `ui` runs `control-perimedi verify` (Simulator XCUITest). Protect main requires `ids`, `openspec`, `domain`, and `ui`.

Coverage is a failing check inside `ids` (and `verify`): `python3 ios/scripts/check-ui-coverage.py --fail-uncovered` fails when a feature-map surface with distinctive IDs is never driven by UI tests. Waiting for `tab.more` is not coverage. More and backup steps live in `testEnglishAppJourney`. Do not add coverage as a separate required check. Protect main requires `ids`, `openspec`, `domain`, and `ui`.

## OpenSpec

Product behavior is specified under `openspec/specs/<capability>/spec.md`.

**Workflow**

1. For behavior changes: update the relevant main specs, **or** open an OpenSpec **change** with delta specs and archive/sync when the change completes.
2. Spec shape: `## Purpose`, `## Requirements`, `### Requirement: …` (SHALL/MUST), and at least one `#### Scenario:` with WHEN/THEN. Describe observable behavior only — not component or file names.
3. Ship OpenSpec updates **in the same commit** as the feature/fix when behavior changes. Archive/sync the change in the same PR so `openspec/specs/` has the new requirements.
4. After editing specs: `openspec validate --specs --strict` when practical.
5. `python3 ios/scripts/check-openspec-sync.py` must pass. CI job `openspec` and `control-perimedi verify` run it. It fails while an active `openspec/changes/<name>/` delta is not yet in `openspec/specs/`.

Do not invent requirements unrelated to the product or the change.
