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
- Prefer clear, short UI copy (+ Med, Cycle settings, + Symptom, Taken / Not taken).

## Domain concepts

- **Medication** — name, form, default dose, optional color (and optional instructions in DB/seed only)
- **Schedule** — times; exclusive mode: every day, specific weekdays, or cyclic (apply N / pause M or week slots). Saved without menstrual-alignment UI (`cycleRule: none`).
- **Period** — logged bleeds; day 1 of a cycle is the first period day
- **Remark** — symptoms/notes (`cycle`, `side_effect`, `note`, `other`) on calendar/diagram
- **DoseLog** — taken / pending (open) per planned dose; UI toggles taken ↔ not taken

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
- Sheets: `Sheet` shell (portaled) + `EditMedicationSheet` (med + schedule), `DayNoteSheet`, `PeriodSettingsSheet`, `MoreSheet`.
- Shared marks: `CycleMarks` (blood drop, symptom spark).
- Styling: Tailwind utilities + shared classes in `index.css` (`.btn-primary`, `.soft-input`, blush/lilac theme).
- Sample data: `lib/seed.ts` — ~26–29 day cycles; load via ⋯ More → Backup.
- Do not commit `node_modules/`, `dist/`, or secrets. No `.env` required.

## When changing features

1. Prefer extending existing sheets over new full pages.
2. Keep med lane labels and dose tracks row-aligned in `CycleDiagram`.
3. Period UI: label + background only (no duplicate red bar).
4. No menstrual “phase” labels (follicular/luteal etc.) — removed by design.
5. After structural changes, run `npm run build`.

## OpenSpec

Product behavior is specified under `openspec/specs/<capability>/spec.md` (capability-level specs, not a single mega-doc).

**Workflow**

1. For behavior changes: update the relevant main specs, **or** open an OpenSpec **change** with delta specs (`## ADDED` / `## MODIFIED` / …) and archive/sync when the change completes.
2. Spec shape: `## Purpose`, `## Requirements`, `### Requirement: …` (SHALL/MUST), and at least one `#### Scenario:` with WHEN/THEN. Describe observable behavior only — not component or file names.
3. Ship OpenSpec updates **in the same commit** as the feature/fix when behavior changes.
4. After editing specs: `openspec validate --specs --strict` when practical.

Do not invent requirements unrelated to the product or the change.
