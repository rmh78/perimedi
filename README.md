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

## Specs (OpenSpec)

Behavior is defined as capability specs in `openspec/specs/<capability>/spec.md`. Each requirement uses SHALL/MUST and WHEN/THEN scenarios. Agent workflow is in `AGENTS.md`.

```bash
openspec list --specs
openspec validate --specs --strict
```

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
