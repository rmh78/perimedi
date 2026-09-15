# PeriMedi feature map

Index of user-facing surfaces. IDs are from `ios/PeriMedi/App/A11yID.swift` unless a file says otherwise. Drive with `AppRobot` via `control-perimedi` (see the skill).

This directory is the maintained verification source. Open one feature file for the change under test. Each file answers the same four questions: what exists, how a user reaches it, how to drive it with the harness, what usually lies. Drift is fixed in the same PR as the product change, or by `/maintain-verification-skill`.

## Baseline preconditions

- macOS with Xcode; `source ios/env.sh` if `xcode-select` is Command Line Tools.
- Isolation is `--run-id` plus simulator UDID (`SIM_UDID` or `SIM_OS`, iPhone 17e only). Do not pass `--checkout`.
- Run `control-perimedi --run-id "$RUN_ID" doctor` and require `doctor: ok` before driving.
- Never drive an instance that was not started by this verification run. Refuse a simulator that already has PeriMedi installed unless this run-id holds the lock.
- Journey launches are `-en -clear -today=2026-03-15 -uiTesting`. Do not pass `-journeyStep` or `-loadSample` on those tests.

## Driving conventions

- Start every recipe from the baseline launch unless the feature file says otherwise (`-remindIn=2`, `-fixture=trends`, `-tabTrends`).
- Prefer `A11yID` strings over coordinates and visible copy. Chrome is en/de; IDs are language-independent. Tests force English with `-en`.
- Treat every identifier as literal. Keep backtick IDs unchanged so `check-feature-map.py` still sees them.
- Type with `clearAndType` / `typeText` after the software keyboard exists. Do not paste.
- Restore isolation with `cleanup` on the same `--run-id`. Do not remove proof artifacts.

## Proof and skip reporting

Do not submit "look, it opens." A simulator that booted is not proof.

- Exercise every reachable entry point listed in the feature file.
- Capture the user action and the resulting state (`TEST SUCCEEDED` plus the values in that file).
- Mutation proof includes a second view (Cycle lane and Month day, banner gone and lane `taken`).
- Report an unreachable path with the command and the unmet precondition. Do not report a skipped entry point as verified through a different path.

## Feature entry contract

Each feature file starts with an H1 and one paragraph. It then uses exactly four H2 sections in this order: `Sub-features`, `How to get to it (user POV)`, `Driving it with A11yID / AppRobot`, `Gotchas`.

## Full sweep

Walk this map top to bottom for a broad regression. Order is Cycle, Month, Trends, More, medication sheet, period sheet, symptom sheet, dose reminders, Home Screen next-dose widget (blocked), doctor visit, backup, then the first-use journey. Driving one convenient entry point is not a sweep.

Practical test walk for that order:

1. `PeriMediUITests/FirstUseJourneyTests/testFirstUseJourney` — Cycle, period, med, symptom, Month
2. `PeriMediUITests/SymptomTrendsTests/testSymptomTrendsNoScores` and `testSymptomTrendsChart` — Trends
3. `PeriMediUITests/FirstUseJourneyTests/testMoreRemindersControls` — More, visit PDF, backup cancel
4. `PeriMediUITests/FirstUseJourneyTests/testDoseReminderTaken` — reminders Taken

PR-wide equivalent: `.grok/skills/verify-perimedi/scripts/control-perimedi verify`.

## Features

- [Cycle](./cycle.md) — home tab, pager, lanes, chips, empty first-use
- [Month](./month.md) — calendar projection of the same store
- [Trends](./trends.md) — cycle chart of days scored and intensity
- [More](./more.md) — language, reminders, visit PDF, backup, privacy
- [Medication sheet](./medication-sheet.md) — create/edit med and schedule over Cycle
- [Period sheet](./period-sheet.md) — log bleeds over Cycle
- [Symptom sheet](./symptom-sheet.md) — scores 1–4 over Cycle
- [Dose reminders](./reminders.md) — in-app banner Taken / Snooze
- [Home Screen next-dose widget](./home-dose-widget.md) — blocked SpringBoard surface; domain + reminder Taken proof
- [Doctor visit PDF](./doctor-visit.md) — More → range → in-app preview
- [Backup / sample](./backup.md) — sample, export, import, clear (cancel in journeys)
- [First-use journey](./journeys.md) — empty app through tracking and Month

Canonical ID source: `ios/PeriMedi/App/A11yID.swift`. Tests: `ios/PeriMediUITests/`. Catalog PNGs: `ios/docs/screens/`.

`python3 ios/scripts/check-ui-coverage.py --fail-uncovered` fails when a surface with distinctive IDs is never driven. `tab.*` does not count as coverage.
