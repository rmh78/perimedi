# Trends (Verlauf)

Fourth bottom tab: Cycle · Trends · Month · More. Own screen under `Features/Trends/`, not a card on Cycle. One point per logged cycle: Y is days scored, dot size is mean intensity 1–4. German tab label **Verlauf**. Spec id `symptom-trends`.

## How to get to it (user POV)

Bottom bar → Trends. Launch flag `-tabTrends` (same pattern as `-tabMonth` / `-tabMore`).

UI tests that need several cycles of scores launch with `-fixture=trends` (not `-loadSample`). Empty store still shows the screen with need-cycles copy.

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| Trends tab | `tab.trends` | Exists on launch. Empty journey taps it. Chart journey may pass `-tabTrends`. |
| Trends screen | `trends.screen` | Shown after the tab or `-tabTrends`. |
| Status | `trends.status` | Empty home: `need-cycles`. Fixture: `ids:hot_flash,sleep,mood` (catalog order of the three most-logged ids). After pinning anxiety: `ids:hot_flash,mood,anxiety`. |
| Empty copy | `trends.empty` | No periods: `need-cycles`. Logged cycles without scores: `no-scores`. |
| Pin | `trends.pin` | Opens the catalog chips. |
| Pin option | `trends.pin.option.{id}` | `A11yID.trendsPinOption(_:)` → `trends.pin.option.{id}`. Pin `anxiety` on the fixture: `trends.status` becomes `ids:hot_flash,mood,anxiety` (sleep dropped). |
| Series | `trends.series.{id}` | `A11yID.trendsSeries(_:)` → `trends.series.{id}`. Fixture defaults: `hot_flash`, `mood`, `sleep`. |
| Dot | `trends.dot.{id}.{cycleStart}` | `A11yID.trendsDot(_:_:)` → `trends.dot.{id}.{cycleStart}`. Fixture `hot_flash` on `2026-01-04`: value contains `count:8` and `mean:1`. On `2026-02-01`: `count:2` and `mean:4`. Sleep on `2026-01-04` does not exist (gap, not a zero). |
| Detail | `trends.detail` | After tapping a dot: value contains `cycle:`, `count:`, and `mean:`. |
| Dose tick | `trends.tick.{cycleStart}` | `A11yID.trendsTick(_:)` → `trends.tick.{cycleStart}`. Fixture: `trends.tick.2026-02-01` value contains `Estrogel` and `2 pumps`. |

## Gotchas

- Y is days scored, never `hot_flash` episode `count`. Size is mean intensity, not the sum.
- Missing scores for an id are a gap: no `trends.dot.{id}.{cycleStart}`, not `count:0`.
- Default three are the ids with the most scored days in the visible span. Pin replaces the lowest of those three.
- Copy is EN/DE via L10n. Tab label is Trends / Verlauf. No “you should…”, no HRT recommendation. No redundant on-screen “Trends” title that only repeats the tab.
- `-uiTesting` skips launch animation so the screen is tappable immediately.
- Domain math is `SymptomTrendLogic.summarize` / `CycleLogic.loggedCycleWindows`. Do not reimplement cycle bounds in the view.
- Do not embed this chart in `CycleView`.
