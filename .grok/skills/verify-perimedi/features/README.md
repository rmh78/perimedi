# PeriMedi feature map

Index of user-facing surfaces. IDs are from `ios/PeriMedi/App/A11yID.swift` unless a file says otherwise. Drive with `AppRobot` via `control-perimedi` (see the skill).

This directory is the maintained verification source. Open one feature file for the change under test. Each file answers the same four questions: what exists, how a user reaches it, how to drive it with the harness, what usually lies. Drift is fixed in the same PR as the product change, or by `/maintain-verification-skill`.

## Baseline preconditions

- macOS with Xcode; `source ios/env.sh` if `xcode-select` is Command Line Tools.
- Isolation is `--run-id` plus simulator UDID (`SIM_UDID` or `SIM_OS`, iPhone 17e only). Do not pass `--checkout`.
- Run `control-perimedi --run-id "$RUN_ID" doctor` and require `doctor: ok` before driving.
- Never drive an instance that was not started by this verification run. Refuse a simulator that already has PeriMedi installed unless this run-id holds the lock.
- The user flow launches with `-en -clear -uiTesting -today=<device date>`. Catalog launches still pin today to `2026-03-15`. Do not pass `-journeyStep`, `-loadSample`, or `-remindIn` on the user flow.

## Driving conventions

- Start every recipe from the baseline launch unless the feature file says otherwise (`-fixture=trends`, `-tabTrends` on catalog launches).
- Prefer `A11yID` strings over coordinates and visible copy. Chrome is en/de; IDs are language-independent. Tests force English with `-en`.
- Treat every identifier as literal. Keep backtick IDs unchanged so `check-feature-map.py` still sees them.
- Type with `clearAndType` / `typeText` after the field is focused. Do not paste.
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

Walk this map top to bottom for a broad regression. Order is Cycle, Month, Trends, More, medication sheet, period sheet, symptom sheet, dose reminders, Home Screen today's-meds widget, doctor visit, backup, then the first-use journey. Driving one convenient entry point is not a sweep.

Practical test walk for that order:

1. `PeriMediUITests/RequiredJourneyTests/testUserFlow` — empty Cycle, one typed medication on the sheet defaults, the lane word Taken then Not taken, one period saved as the card opens, one symptom, Month, Trends with that symptom turned off so the chart drops the point, More, Back from the visit preview to the picker, one medium widget Take

PR-wide equivalent: `.grok/skills/verify-perimedi/scripts/control-perimedi verify`. A pull request runs `testUserFlow` and does not run `ScreenCatalogTests`. Local `verify` and the nightly full suite discover `testUserFlow` and the catalog writer.

## Features

- [Cycle](./cycle.md) — home tab, pager, lanes, chips, empty first-use
- [Month](./month.md) — calendar projection of the same store
- [Trends](./trends.md) — cycle chart of days scored and intensity
- [More](./more.md) — language, reminders, visit PDF, backup, privacy
- [Medication sheet](./medication-sheet.md) — create/edit med and schedule over Cycle
- [Period sheet](./period-sheet.md) — log bleeds over Cycle
- [Symptom sheet](./symptom-sheet.md) — scores 1–4 over Cycle
- [Dose reminders](./reminders.md) — in-app banner Taken / Snooze
- [Home Screen today's-meds widget](./home-dose-widget.md) — one medium Take inside `testUserFlow`. A pull request runs that step. The nightly full suite runs the same test.
- [Doctor visit PDF](./doctor-visit.md) — More → range → in-app preview. Back returns to the same picker. Close returns to More.
- [Backup / sample](./backup.md) — catalog waits for `more.sample` after the visit preview and does not tap it
- [First-use journey](./journeys.md) — empty app through tracking and Month

Canonical ID source: `ios/PeriMedi/App/A11yID.swift`. Tests: `ios/PeriMediUITests/`. Catalog PNGs: `ios/docs/screens/`.

`python3 ios/scripts/check-ui-coverage.py --fail-uncovered` fails when a surface with distinctive IDs is never driven. `tab.*` does not count as coverage.
