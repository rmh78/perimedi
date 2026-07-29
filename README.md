# PeriMedi

**Perimenopause medication** companion: track doses, periods, and symptoms.

Browser-only SPA — all data stays in **IndexedDB** on your device (no server, no account).

## Features

- **Home-first**: log doses, period, and symptoms; edit meds and schedules in place
- Medications (pill, cream, drops, injection, other) with default doses
- Schedules: times, weekdays or every day, optional **apply N / pause M days** cycles (e.g. 14/14 progesterone-style demo)
- Optional alignment to period days or cycle-day range
- Cycle view: meds, period days, symptoms, day selection
- Month calendar with period and symptom markers
- **⋯ More**: backup (export/import/sample), period settings & history

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
