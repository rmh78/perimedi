# PeriMedi — agent notes

Perimenopause medication companion: track doses, periods, and symptoms.

The **product is a native iOS app** (`ios/`). Data lives in on-device SwiftData, with optional Apple iCloud for the same Apple ID. There is no PeriMedi server or product account.

The original **web companion** is in `web/` (React + Dexie/IndexedDB). Keep it buildable as the reference implementation and JSON backup producer.

## Stack

- **iOS:** SwiftUI, SwiftData, CloudKit (fallback to local-only), `PeriMediDomain` Swift package
- **Web:** React 19 + Vite + TypeScript + Tailwind CSS v4 + Dexie (`perimedi`) + React Router + date-fns

## Project layout

```
ios/                 # Xcode app + PeriMediDomain package
  PeriMedi/          # SwiftUI app (Cycle / Month / More, sheets, SwiftData)
  Sources/           # portable domain (cycle, schedule, therapy, backup, seed)
  Tests/             # XCTest for domain (mirrors web/src/lib tests)
  docs/              # iCloud device-switch notes
web/                 # Vite/React companion
  src/components/    # web UI
  src/lib/           # original domain (oracle for the Swift port)
openspec/            # shared product specs
```

## Product rules

- **Cycle / Month / More** via bottom nav. Cycle is the default home. Edit meds/schedules/symptoms via sheets, not extra full pages.
- **Not medical advice** — sample data and UI are a personal demo, not clinical guidance.
- Keep privacy local: never introduce a PeriMedi server or analytics without explicit user request. Apple iCloud (user’s Apple ID) is the allowed sync path.
- Prefer clear, short UI copy (+ Med, Cycle settings, + Symptom, Taken / Not taken).

## Domain concepts

- **Medication** — name, form, default dose, optional color
- **Schedule** — times; exclusive mode: every day, specific weekdays, or cyclic (apply N / pause M or week slots). Saved without menstrual-alignment UI (`cycleRule: none` in the editor).
- **Period** — logged bleeds; day 1 of a cycle is the first period day
- **Remark** — symptoms/notes (`cycle`, `side_effect`, `note`, `other`)
- **DoseLog** — taken / pending (open) per planned dose

Schedule expansion: `ios/Sources/PeriMediDomain` (port of `web/src/lib`).

## Commands

```bash
# Web companion
npm --prefix web install
npm --prefix web run dev
npm --prefix web test
npm --prefix web run build

# iOS domain tests (no Simulator)
source ios/env.sh    # if xcode-select still points at Command Line Tools
swift test --package-path ios

# iOS Simulator build
xcodebuild -project ios/PeriMedi.xcodeproj -scheme PeriMedi \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -derivedDataPath ios/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Root `npm test` / `npm run build` delegate to `web/`.

If `xcode-select -p` is Command Line Tools, either `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` or `source ios/env.sh` (`DEVELOPER_DIR`).

Simulator signing does not require a paid team. Add an Apple ID in Xcode → Accounts later for device / production CloudKit. See `ios/docs/icloud-device-switch.md`.

## Conventions

- **i18n:** iOS chrome via `LocaleController` + `L10n` (en/de) and `Localizable.xcstrings`. Language control lives in More; preference is `AppStorage` (`perimedi.locale`). Default German if device preferred languages include German. User-entered text is never translated.
- **Layout review:** iOS — run on a narrow iPhone Simulator (iPhone 17e) and screenshot; do not use Playwright for the native app. Web — Playwright SE **375×667** (`npm run shot:se` from `web/` with Vite running).
- iOS sheets: `MedicationSheet`, `PeriodSheet`, `SymptomSheet` presented over Cycle.
- Sample data: `SampleData.payload()` (same sketch as `web/src/lib/seed.ts`) via More → Backup.
- JSON backup is `ExportPayload` version 1 (shared with the web companion).
- Do not commit `node_modules/`, `dist/`, `ios/DerivedData`, `ios/.build`, or secrets. No `.env` required.

## When changing features

1. Prefer extending existing sheets over new full pages.
2. Keep med lane labels and dose tracks row-aligned on Cycle.
3. Period UI: label + background only (no duplicate red bar).
4. No menstrual “phase” labels (follicular/luteal etc.).
5. After structural changes: `swift test --package-path ios` and an iOS Simulator build; if `web/` changed, `npm --prefix web run build`.

## OpenSpec

Product behavior is specified under `openspec/specs/<capability>/spec.md`.

**Workflow**

1. For behavior changes: update the relevant main specs, **or** open an OpenSpec **change** with delta specs and archive/sync when the change completes.
2. Spec shape: `## Purpose`, `## Requirements`, `### Requirement: …` (SHALL/MUST), and at least one `#### Scenario:` with WHEN/THEN. Describe observable behavior only — not component or file names.
3. Ship OpenSpec updates **in the same commit** as the feature/fix when behavior changes.
4. After editing specs: `openspec validate --specs --strict` when practical.

Do not invent requirements unrelated to the product or the change.
