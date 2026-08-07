## Why

PeriMedi is used on phones (including narrow devices like iPhone SE), tablets, and desktops. Day cells on the cycle chart and month grid must stay usable under a finger; sheets must stay closable; and primary destinations must not force one long scrolling “Home” page. Work has evolved from a single Home surface into a **multi-screen shell** with Cycle as the default, while keeping touch-friendly chart scrolling and a reliable sheet shell.

## What Changes

- **Bottom navigation** among **Cycle**, **Month**, and **More** only (no separate **Today** primary screen). App entry lands on **Cycle**.
- **Shared selected date** across Cycle and Month; Cycle provides a **Today** control that selects today and scrolls the plot when needed.
- Cycle chart: **compact day columns** (denser than a strict 44px minimum so more of the cycle fits on SE) with **horizontal scroll** when needed; **sticky** med/cycle labels.
- Cycle **header** holds day paging (prev / day · date / next), Today (same ghost button style as Month), status chips, and **icon actions** (add med, cycle settings, add symptom)—no nested selected-day card and no floating day badge over the plot.
- Month: month name + Prev/Today/Next only (no “Month” page title); period drops sit **beside the day number** so they are not clipped by cell borders.
- More: glass card with **Language** and **Backup** sections only (no Period settings tab); shared app button styles (`btn-primary` / `btn-ghost` / `btn-soft`).
- **Sheets**: viewport-bounded panel, always-reachable close, body scroll; **horizontal inset** so dialogs are not edge-to-edge; medication **color palette** laid out in **two rows** so it fits on small widths.
- EN/DE chrome via existing i18n; client-only SPA, no server.

## Capabilities

### New Capabilities
- `responsive-layout`: Viewport-adaptive shell, multi-screen bottom nav, shared touch/spacing rules, and sheet inset/closability across phone, tablet, and desktop.

### Modified Capabilities
- `cycle-diagram`: Compact day columns + horizontal scroll + sticky labels; selection highlight on the plot; header day paging and Today scroll-into-view; icon day actions; denser cycle-days strip.
- `month-calendar`: Touch-friendly cells within content width; period marks fully visible; no redundant page title.
- `home-surface`: Multi-screen shell (Cycle / Month / More); shared selected date; no Today primary screen.

## Impact

- Routing and bottom nav (`App`, `nav`, `BottomNav`); Cycle/Month/More pages; `CycleDiagram`, sheets (`Sheet`, med/symptom/period), `MorePanel`.
- Light CSS/layout + pure layout helpers/tests; no new runtime dependencies.
- Manual check on SE-class width (~320–375), tablet, desktop.
- Privacy and local-only data model unchanged.
