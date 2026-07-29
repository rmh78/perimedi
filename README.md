# PeriMedi

**Perimenopause medication** companion: track doses, periods, and symptoms.

Browser-only SPA — all data stays in **IndexedDB** on your device (no server, no account).

## Features

- **Home-first**: meds, cycle chart, month calendar, and day detail on one page
- Medications with form icons, custom colors, default dose, and integrated schedule
- Schedules: every day, specific weekdays, or cyclic apply/pause — not mixed
- Mark doses taken/not taken via med icon; taken days tinted with med color
- Cycle diagram: day selection overlay, period blood drops, symptom marks
- Month calendar: cycle start/end marks, cycle-day badges, period drops
- Day card: period/symptom summary, + Med, cycle settings, + Symptom
- **⋯ More**: backup (export/import/sample/clear), period settings also via day card

## Requirements

Agents must keep this section updated on every commit that changes product behavior (see `AGENTS.md`).

### Functional requirements

- **FR-01** Home is the primary surface: view cycle, meds, calendar, and open edit sheets without a separate care section.
- **FR-02** User can add and edit a medication including form, default dose, color, and schedule in one dialog (no separate schedule-only flow for the primary schedule).
- **FR-03** Medication form types: pill, cream, drops, injection, other; each has an icon that fills the med avatar.
- **FR-04** User can choose a color per medication from a single-row palette (including light pinks/roses); color applies to icon ring, dose bands, and taken-day fills.
- **FR-05** Schedule mode is exclusive: every day, specific weekdays, or cyclic (apply N / pause M or week slots) — not weekdays and cyclic together.
- **FR-06** User can set one or more clock times per day for a schedule (“take at”); dose is the medication default (no per-schedule dose override in UI).
- **FR-07** User can mark a medication’s doses for the selected day as taken or not taken by tapping the med icon (toggle).
- **FR-08** Cycle chart shows one lane per medication with dose segments across cycle days and a semi-transparent selection column for the selected date.
- **FR-09** Selecting a day on the cycle strip, med bands, or month calendar updates the shared selected date and cycle window.
- **FR-10** Cycle window is anchored to the period that defines cycle day for the selected date (not only the latest period).
- **FR-11** Cycle day 1 is the first day of a logged (or predicted) period; cycle start markers must not appear mid-bleed of another period.
- **FR-12** User can view and edit period settings (average cycle/period length) and period history (add/edit/delete) via cycle settings.
- **FR-13** Cycle day strip shows blood-drop icons for period days (solid logged, lighter predicted) and symptom marks on a separate row.
- **FR-14** Month calendar shows cycle start/end boundaries, cycle-day badges (e.g. D12), period drops, symptoms, and dose status dots.
- **FR-15** Selected-day card (below the chart) shows period and symptom summary and primary actions: + Med, cycle settings, + Symptom.
- **FR-16** User can log symptoms/notes for the selected date via a sheet opened from the day card.
- **FR-17** Hero shows today’s date, cycle day heading (no duplicate day chip), next period estimate, and today’s taken/total dose progress — without period/symptom action buttons.
- **FR-18** User can export/import all local data as JSON, load sample data, or clear data (More menu).
- **FR-19** Sample data demonstrates a perimenopause-oriented med set with ~26–29 day cycles, dose logs, and non-overlapping periods.


### Non-functional requirements

- **NFR-01** Client-only SPA: no backend account or server-side storage for app data.
- **NFR-02** All user data persists in browser IndexedDB (Dexie, database name `perimedi`) on the user’s device.
- **NFR-03** No environment variables or secrets required to run or deploy the static app.
- **NFR-04** Clearing site data may wipe the local database; export is the backup path.
- **NFR-05** UI must not present itself as medical advice; sample data is fictional demo content.
- **NFR-06** Sheets/modals must render above page content (portal to `document.body`) and not be clipped by overflow parents.
- **NFR-07** Production build must pass TypeScript check and Vite build (`npm run build`).
- **NFR-08** Prefer compact, clear UI copy; avoid duplicate primary actions (e.g. hero period/symptom buttons removed when available elsewhere).
- **NFR-09** Stack baseline: React + Vite + TypeScript + Tailwind + Dexie + React Router + date-fns.

## Stack

- React + Vite + TypeScript + Tailwind CSS
- Dexie.js (IndexedDB)
- React Router, date-fns

## Local development

```bash
npm install
npm run dev
```

Open the URL Vite prints (usually `http://localhost:5173`).

```bash
npm run build
npm run preview
```

## Deploy

Static hosting (e.g. Vercel):

```bash
npx vercel
```

No environment variables required.

## Privacy

- Storage is **per browser / device**
- Clearing site data deletes the local database
- Use **⋯ More → Backup → Export** for backups

## License

Personal project — use and modify freely.
