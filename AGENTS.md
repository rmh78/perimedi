# PeriMedi — agent notes

Perimenopause medication companion: track doses, periods, and symptoms.

The **product is a native iOS app** (`ios/`). Data lives in on-device SwiftData, with optional Apple iCloud for the same Apple ID. There is no PeriMedi server, product account, or website.

## Stack

SwiftUI, SwiftData, CloudKit (fallback to local-only), `PeriMediDomain` Swift package.

## Project layout

```
ios/                 # Xcode app + PeriMediDomain package
  PeriMedi/          # SwiftUI app (Cycle / Month / More, sheets, SwiftData)
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

## Commands

```bash
# Domain tests (no Simulator)
source ios/env.sh    # if xcode-select still points at Command Line Tools
swift test --package-path ios

# iOS Simulator build
xcodebuild -project ios/PeriMedi.xcodeproj -scheme PeriMedi \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -derivedDataPath ios/DerivedData CODE_SIGNING_ALLOWED=NO build

# iOS UI tests (iPhone 17e — not iPhone 17)
xcodebuild test -project ios/PeriMedi.xcodeproj -scheme PeriMedi \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -derivedDataPath ios/DerivedData CODE_SIGNING_ALLOWED=NO
```

UI tests are one first-use journey (`FirstUseJourneyTests`) plus a dose-reminder journey. They launch with `-en -clear -today=2026-03-15` and tap real controls. They never pass `-journeyStep` or `-loadSample`. Watch **iPhone 17e** in Simulator (Window → iPhone 17e); iPhone 17 is a different device.

`JourneyScript` / `ios/scripts/shot-journey.sh` remain optional visual capture (seeded store snapshots). They are not the interaction proof.

If `xcode-select -p` is Command Line Tools, either `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` or `source ios/env.sh` (`DEVELOPER_DIR`).

Simulator signing does not require a paid team. Add an Apple ID in Xcode → Accounts later for device / production CloudKit. See `ios/docs/icloud-device-switch.md`.

## Conventions

- **i18n:** iOS chrome via `LocaleController` + `L10n` (en/de) and `Localizable.xcstrings`. Language control lives in More; preference is `AppStorage` (`perimedi.locale`). Default German if device preferred languages include German. User-entered text is never translated.
- **Layout review:** run on a narrow iPhone Simulator (iPhone 17e) and screenshot.
- iOS sheets: `MedicationSheet`, `PeriodSheet`, `SymptomSheet` presented over Cycle.
- Sample data: `SampleData.payload()` via More → Backup.
- JSON backup is `ExportPayload` version 1.
- Do not commit `ios/DerivedData`, `ios/.build`, or secrets. No `.env` required.

## When changing features

1. Prefer extending existing sheets over new full pages.
2. Keep med lane labels and dose tracks row-aligned on Cycle.
3. Period UI: label + background only (no duplicate red bar).
4. No menstrual “phase” labels (follicular/luteal etc.).
5. After structural changes: `swift test --package-path ios` and an iOS Simulator build; if UI behavior changed, also `xcodebuild test` on iPhone 17e.
6. After any iOS UI change: rebuild, **uninstall**, reinstall, and launch on **iPhone 17e** so the Simulator is not showing a leftover install. Do not leave a stale app on the device.

## Feature map (for agents)

When driving or checking a screen, read `.grok/skills/verify-perimedi/` first. `features/` maps each surface to real `A11yID` strings and `AppRobot`. Do not invent identifiers.

## OpenSpec

Product behavior is specified under `openspec/specs/<capability>/spec.md`.

**Workflow**

1. For behavior changes: update the relevant main specs, **or** open an OpenSpec **change** with delta specs and archive/sync when the change completes.
2. Spec shape: `## Purpose`, `## Requirements`, `### Requirement: …` (SHALL/MUST), and at least one `#### Scenario:` with WHEN/THEN. Describe observable behavior only — not component or file names.
3. Ship OpenSpec updates **in the same commit** as the feature/fix when behavior changes.
4. After editing specs: `openspec validate --specs --strict` when practical.

Do not invent requirements unrelated to the product or the change.
