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

### Layout screenshots (iPhone SE 375)

With the app running (`npm run dev` or preview):

```bash
npm run shot:se
# or: BASE_URL=http://127.0.0.1:4173 npm run shot:se
```

Writes PNGs under `shots/` (gitignored) at **375×667** for layout review.

## Deploy

Static SPA — no server, no env vars. Output is `dist/` after `npm run build`.

### Vercel (recommended)

The repo includes `vercel.json` so client-side routes fall back to `index.html`. Local CLI link state lives in `.vercel/` (gitignored).

```bash
npm install
npx vercel          # preview deployment
npx vercel --prod   # production
```

Or connect the GitHub repo in the [Vercel dashboard](https://vercel.com) for automatic deploys on push to `main`.

No environment variables are required. App data still lives only in each visitor’s browser (IndexedDB); hosting does not sync data across devices.

## Privacy

- Storage is **per browser / device**
- Clearing site data deletes the local database
- Use **⋯ More → Backup → Export** for backups

## License

Personal project — use and modify freely.
