# PeriMedi — agent notes

Perimenopause medication companion: track doses, periods, and symptoms. Client-only SPA; data lives in IndexedDB (no backend).

## Stack

- React 19 + Vite + TypeScript + Tailwind CSS v4 (`@tailwindcss/vite`)
- Dexie (IndexedDB database name: `perimedi`)
- React Router (single route: Home)
- date-fns

## Project layout

```
src/
  components/   # UI: diagram, sheets, cards
  pages/        # HomePage only
  db/           # Dexie schema + write actions
  hooks/        # liveQuery wrappers
  lib/          # pure logic: cycle, schedule expansion, therapy cycles, seed
  types.ts      # shared domain types
```

## Product rules

- **Home-first**: edit meds/schedules/symptoms via slide-over sheets on Home, not a separate “care” page.
- **Not medical advice** — sample data and UI are a personal demo, not clinical guidance.
- Keep privacy local: never introduce a server or analytics without explicit user request.
- Prefer clear, short UI copy (Start period, Open/Taken/Skipped, + Med).

## Domain concepts

- **Medication** — name, form, default dose
- **Schedule** — times, weekdays (empty = every day), optional therapy cycle (apply N / pause M days), optional menstrual alignment (`period_only` / `cycle_day_range`)
- **Period** — logged bleeds; drives cycle day numbering
- **Remark** — symptoms/notes (`cycle`, `side_effect`, `note`, `other`) shown on calendar/diagram
- **DoseLog** — taken / skipped / open (pending) per planned dose slot

Schedule expansion: `lib/schedule.ts` + `lib/therapyCycle.ts` + `lib/cycle.ts`.

## Commands

```bash
npm install
npm run dev      # Vite dev server
npm run build    # tsc -b && vite build
npm run preview
```

## Conventions

- Functional React components; state via hooks; Dexie `liveQuery` for reactive data.
- Sheets: `Sheet` shell + `EditMedicationSheet`, `EditScheduleSheet`, `DayNoteSheet`, `MoreSheet`.
- Styling: Tailwind utilities + shared classes in `index.css` (`.btn-primary`, `.soft-input`, blush/lilac theme).
- Sample data: `lib/seed.ts` — perimenopause-oriented demo; load via ⋯ More → Backup.
- Do not commit `node_modules/`, `dist/`, or secrets. No `.env` required.

## When changing features

1. Prefer extending existing sheets over new full pages.
2. Keep med lane labels and dose tracks row-aligned in `CycleDiagram`.
3. Period UI: label + background only (no duplicate red bar).
4. No menstrual “phase” labels (follicular/luteal etc.) — removed by design.
5. After structural changes, run `npm run build`.
