## Context

See proposal.md. The cycle chart originally packed many days into full width (hard to tap on SE). Sheets could push close controls out of reach. Product direction then moved from a single long Home to a **multi-screen shell** with denser cycle columns so more days fit without losing sticky labels and horizontal scroll.

## Goals / Non-Goals

**Goals:**
- Multi-screen shell: Cycle (default), Month, More via bottom navigation.
- Cycle plot: sticky identity column + horizontally scrollable day plot; selected day always clear.
- Finger-friendly primary controls (nav, Today, day cells, sheet close); denser day *columns* on the cycle plot so more of a cycle is visible on SE (trade-off vs strict 44px day width).
- Sheets always closable and **inset** from left/right (and safe areas).
- Homogeneous page chrome (glass cards, shared button classes).

**Non-Goals:**
- Separate mobile codebase or native apps.
- Pinch-zoom as the only way to hit a day.
- Redesigning clinical/domain logic or sample-data content.
- A dedicated Today primary screen or period-settings tab on More (cycle settings remain reachable from Cycle).

## Concept: Multi-screen + scrollable cycle

```
Bottom nav:  [ Cycle ]  [ Month ]  [ More ]

Cycle header:  ← Day N · date →   [Today]
               chips · [med+] [period] [symptom+]
Plot: sticky labels | day strip + med bands (scroll →)
```

1. **Default route** — Cycle at `/`; legacy `/today` and `/cycle` resolve to Cycle.
2. **Day width** — plot `min-width ≈ cycleLen × dayMin` with a **compact** dayMin (implementation: 22 CSS px) so ~8+ days fit beside sticky labels on 375px; scroll for the rest.
3. **One horizontal scroller** for day strip + med tracks; sticky label column.
4. **Selection** — highlight in plot coordinates (scrolls with content); **no** floating day title badge (day text lives in the header).
5. **Day actions** — icon buttons in the Cycle header (pill image + plus, blood-drop cycle settings, symptom spark); same action affordances as the former selected-day card.
6. **Today** — ghost-style control next to day paging; selects today and scrolls the plot into view when overflowed.

## Decisions

### 1. Day column density

**Choice:** Prefer denser columns (~half of a classic 44px touch minimum) so more of the cycle is on-screen on SE, while keeping horizontal scroll and sticky labels. Selectable med-band hit areas remain the full column height.

**Trade-off:** Narrower than HIG 44px width; acceptable because selection is also driven by header paging and the month screen.

### 2. Structure of CycleDiagram

- Sticky label column: cycle meta + med name/taken.
- Plot: compact cycle-days strip above med bands; selection overlay plot-only.
- Header (in main card): day pager + Today + chips + action icons.

### 3. Month calendar

- Header: **MMMM yyyy** + Prev / Today / Next (no “Month” title).
- Period marks: blood drop **next to the day number** (left cluster) so adjacent cells never clip the glyph.
- Keep 7-column grid; no page-level horizontal scroll.

### 4. Multi-screen shell

**Choice:** Bottom tabs Cycle / Month / More. Remove Today as a tab and primary page. Shared `SelectedDateContext` for selection across Cycle and Month.

### 5. Sheets

- Portaled panel: max-height with `dvh`/`vh`, header `shrink-0`, body scroll.
- **Inset padding** left/right (and safe-area) so dialogs are not full-bleed edge-to-edge.
- Medication color palette: **two-row grid** so all swatches fit on SE without horizontal scroll.

### 6. More page

- Glass card, no page title.
- Two bordered sections: **Language** (EN/DE with `btn-primary`/`btn-ghost`) and **Backup** (actions with `btn-ghost` / `btn-soft`).
- No Period settings on More (period/cycle settings via Cycle action → period sheet).

### 7. No new libraries

CSS + existing React layout only.

## Risks / Trade-offs

- **[Denser day columns]** → Slightly harder precision on the plot; mitigated by header paging and Month.
- **[Long cycles → more scrolling]** → Sticky labels + Today + day pager.
- **[Double scroll]** → Chart scroller only when plot overflows; page scrolls vertically for content.
- **[Sheet safe areas]** → Combined CSS padding and env(safe-area-inset-*).

## Migration Plan

1. Sheet shell (closable + inset) — done.
2. Multi-screen nav; drop Today page — done.
3. Cycle header / compact plot / icon actions — done.
4. Month / More chrome polish — done.
5. Med color two-row picker — done.
6. Keep OpenSpec main + change artifacts aligned; archive when product is stable.

Rollback: layout/route commits only; domain data unaffected.

## Open Questions

None blocking. DayMin may be retuned if SE readability or tap accuracy regresses.
