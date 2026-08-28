# Cycle

Home. Bottom tab. Default after launch.

## Sub-features

- Empty first-use: intro copy + empty-meds chip until a period and a medication exist
- Cycle pager (previous / next / today / label)
- Action buttons: add med, cycle settings (period), add symptom
- Med lanes (name slug) with status and edit
- Day strip under the plot
- Period chip and symptom-score chips on the plot

## How to get to it (user POV)

Open the app, or tap Cycle in the bottom bar. Sheets for med / period / symptom open over Cycle, not as extra pages.

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| Cycle tab | `tab.cycle` | Exists after `AppRobot.launch()` |
| Add medication | `cycle.action.med` | Opens `sheet.med` |
| Cycle settings (period) | `cycle.action.period` | Opens `sheet.period` |
| Add symptom | `cycle.action.symptom` | Opens `sheet.symptom` |
| Empty meds chip | `cycle.empty.meds` | First-use value contains `need-period` and `need-med`. After a period only: exactly `need-med`. Gone once a lane exists. |
| Intro | `cycle.intro` | Present on empty home. Gone after a period is logged. |
| Period chip | `cycle.chip.period` | Exists when the visible range includes a logged period (pager back in the first-use journey). |
| Symptom chip | `cycle.chip.score.{id}` | Built in `CycleView`, **not** in the `A11yID` enum. After logging hot flash 3, `cycle.chip.score.hot_flash` value contains `strong` (en). |
| Pager prev / next / today / label | `cycle.pager.prev` `cycle.pager.next` `cycle.pager.today` `cycle.pager.label` | Prev changes label; today restores it. |
| Lane | `cycle.lane.{slug}` | Slug from `A11yID.slug(name)`: lowercased, whitespace/`_` → `-`. `Estrogen` → `cycle.lane.estrogen`. |
| Lane status | `cycle.lane.{slug}.status` | Tap the lane to mark taken. Values: `taken`, `not-taken`. |
| Lane edit | `cycle.lane.{slug}.edit` | Opens the medication sheet for that med. |
| Strip day | `cycle.strip.day.{yyyy-MM-dd}` | Period days include `period` in the value. |

`AppRobot.launch()` waits for `tab.cycle` and `cycle.action.med`.

## Gotchas

- IDs are language-independent; chrome copy is en/de. Tests launch `-en`.
- `cycle.chip.score.{id}` is missing from `A11yID.swift` — still real, used by `FirstUseJourneyTests`.
- Tapping a lane toggles dose status. Editing is the separate `.edit` control.
- Keep med lane labels and dose tracks row-aligned. Period UI is label + background only (no duplicate red bar). No follicular/luteal labels.
