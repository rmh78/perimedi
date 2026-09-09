# Trends (Verlauf)

Fourth bottom tab: Cycle · Trends · Month · More. Own screen under `Features/Trends/`, not a card on Cycle. One point per logged cycle: Y is days scored, dot size is mean intensity 1–4. German tab label **Verlauf**. Spec id `symptom-trends`. Chart first; catalog lives in a Change sheet (`Show on chart` / `Im Diagramm zeigen`).

## How to get to it (user POV)

Bottom bar → Trends. Launch flag `-tabTrends` (same pattern as `-tabMonth` / `-tabMore`).

UI tests that need several cycles of scores launch with `-fixture=trends` (not `-loadSample`). Cycles with no scores use `-fixture=trends-noscores`. Empty store still shows the screen with need-cycles copy. Change and the catalog sheet appear only when a chart can be drawn.

## Driving it with A11yID / AppRobot

| Control | ID | Proof |
|---|---|---|
| Trends tab | `tab.trends` | Exists on launch. Empty journey taps it. Chart journey may pass `-tabTrends`. |
| Trends screen | `trends.screen` | Shown after the tab or `-tabTrends`. |
| Status | `trends.status` | Empty home: `need-cycles`. Fixture: `ids:hot_flash,sleep,mood` (catalog order of the three most-logged ids). After selecting anxiety: `ids:hot_flash,mood,anxiety`. |
| Empty copy | `trends.empty` | No periods: `need-cycles`. Logged cycles without scores (`-fixture=trends-noscores`): `no-scores`. Empty journeys have no `trends.change` and no series chips. |
| Intro | `trends.intro` | Not on the default chart (picker moved to the sheet). Missing on empty. |
| Axis label | `trends.axis` | Chart only. Value `days-scored`. |
| Size key | `trends.sizeKey` | Chart only. Bigger dot = stronger. |
| Change | `trends.change` | Chart only, bottom of the card. Opens `sheet.trends`. Missing on empty. |
| Sheet | `sheet.trends` | After `trends.change`. Title Show on chart / Im Diagramm zeigen. |
| Done | `trends.done` | Closes the sheet. `sheet.close` also closes. |
| Group title | `trends.group.{id}` | `A11yID.trendsGroup(_:)` → `trends.group.{id}`. Body / mood / urogenital only inside the sheet. |
| Series | `trends.series.{id}` | `A11yID.trendsSeries(_:)` → `trends.series.{id}`. On the chart: stacked legend of the three selected, value `on`. Off ids exist only in the sheet. Fixture defaults: `hot_flash`, `mood`, `sleep` on the legend; `anxiety` after opening the sheet, value `off`. Selecting `anxiety` turns it `on` and `sleep` `off`. |
| Dot | `trends.dot.{id}.{cycleStart}` | `A11yID.trendsDot(_:_:)` → `trends.dot.{id}.{cycleStart}`. Fixture `hot_flash` on `2026-01-04`: value contains `count:8` and `mean:1`. On `2026-02-01`: `count:2` and `mean:4`. Sleep on `2026-01-04` does not exist (gap, not a zero). |
| Detail | `trends.detail` | After tapping a hot-flash dot: value contains `id:hot_flash`, `cycle:`, `count:`, and `mean:`. User-facing copy says average, not mean. |
| Plot | `trends.plot` | Horizontal scroller for cycle points. Latest cycles are in view first; pan left for older ones when they do not fit. |
| Dose tick | `trends.tick.{cycleStart}` | `A11yID.trendsTick(_:)` → `trends.tick.{cycleStart}` on the plot, not a caption under the card. Fixture: `trends.tick.2026-02-01` value contains `Estrogel` and `2 pumps`. Tap shows `trends.tickCopy`. |
| Tick copy | `trends.tickCopy` | After tapping a dose tick. Context only, not a cause. |

## Gotchas

- Default chart is plot → stacked selected names → size key → Change. No chip cloud, no group titles, no “Select the symptoms…”.
- Empty states hide Change and the catalog sheet.
- Y is days scored, never `hot_flash` episode `count`. Size is mean intensity, not the sum.
- Missing scores for an id are a gap: no `trends.dot.{id}.{cycleStart}`, not `count:0`.
- Default three are the ids with the most scored days in the visible span. Selecting a fourth in the sheet replaces the lowest of those three. Max three selected.
- Copy is EN/DE via L10n. Tab label is Trends / Verlauf. German mood group is Stimmung; the mood chip is Niedrige Stimmung. DE dose unit is Hub, not pump (name stays as stored). No “you should…”, no HRT recommendation. No redundant on-screen “Trends” title that only repeats the tab.
- `-uiTesting` skips launch animation so the screen is tappable immediately.
- Sample data has four scored cycles. Trends only plots cycles that have scores; empty period history is not enough.
- If more cycles are shown than fit, pan the plot horizontally (`trends.plot`). It opens on the most recent cycles.
- Domain math is `SymptomTrendLogic.summarize` / `CycleLogic.loggedCycleWindows`. Do not reimplement cycle bounds in the view.
- Do not embed this chart in `CycleView`.
- Screen catalog PNGs: `ios/docs/screens/`. Review Files changed, not PR comment galleries.
