## 1. Sheets closable on SE (priority)

- [x] 1.1 Fix shared sheet shell so the panel is viewport-bounded (prefer `dvh` max-height + safe-area) with a non-scrolling header and close control
- [x] 1.2 Make sheet body the only vertical scroll region (`min-h-0` flex child) so long content never pushes close off-screen
- [x] 1.3 Ensure backdrop dismiss remains tappable on phone; enlarge close hit target to ~44×44 if needed
- [x] 1.4 Verify on iPhone SE-class width: open sheet, scroll body if needed, close via × and via backdrop
- [x] 1.5 Inset sheets from left/right (and safe-area) so dialogs are not edge-to-edge

## 2. Shell and multi-screen navigation

- [x] 2.1 Confirm mobile viewport meta in `index.html`
- [x] 2.2 Bottom nav: Cycle, Month, More only; app entry = Cycle; remove Today primary page/tab
- [x] 2.3 Shared selected date across Cycle and Month
- [x] 2.4 Homogeneous glass cards; drop redundant Month/More page titles

## 3. Cycle chart

- [x] 3.1 Compact day-column minimum + plot width `max(available, cycleLen × dayMin)` with horizontal scroll
- [x] 3.2 Sticky med/cycle labels; single scroll region for day strip + med bands
- [x] 3.3 Selection overlay in plot coordinates (no floating day badge over the plot)
- [x] 3.4 Header: day paging, Today (ghost style), chips, icon actions (med / cycle / symptom)
- [x] 3.5 Compact cycle-days strip height
- [x] 3.6 Today + initial mount scroll selected/today column into view when plot overflows
- [x] 3.7 Verify SE: page days, Today, scroll plot, sticky labels

## 4. Month and More polish

- [x] 4.1 Month header month/year + Prev/Today/Next; period drops beside day number (no clip)
- [x] 4.2 More: Language + Backup sections only; shared button styles; no Period settings tab
- [x] 4.3 Medication color palette in two rows for narrow sheets

## 5. Verify

- [x] 5.1 Manual pass at SE-class width: nav, Cycle header, chart scroll, Month marks, More, sheets close + inset
- [x] 5.2 Manual pass at tablet/desktop
- [x] 5.3 `npm run build` and unit tests for layout/nav helpers
- [x] 5.4 OpenSpec main `home-surface` aligned with multi-screen shell; change artifacts updated
