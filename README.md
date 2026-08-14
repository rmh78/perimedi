# PeriMedi

**Perimenopause medication** companion: track doses, periods, and symptoms.

The product is a **native iOS app** (`ios/`) with on-device SwiftData and optional Apple iCloud sync for the same Apple ID. There is no PeriMedi account or backend.

The original **web companion** lives in `web/` as the reference implementation and JSON backup producer (IndexedDB only).

This is a personal demo, not medical advice.

## Features

- **Cycle / Month / More** via bottom navigation (Cycle is the home screen)
- Medications with form, custom colors, default dose, and integrated schedule
- Schedules: every day, specific weekdays, or cyclic apply/pause — not mixed
- Mark doses taken / not taken
- Cycle day plot, period/symptom marks, month calendar
- **More**: language (EN/DE) and backup (export/import/sample/clear)
- Cycle settings and period history via a sheet

## Layout

```
ios/          Native SwiftUI app + PeriMediDomain package
web/          Vite/React companion (oracle + JSON export)
openspec/     Product specs (`specs/<capability>/spec.md`)
```

## iOS app

See [`ios/README.md`](ios/README.md). Quick start:

```bash
source ios/env.sh   # if xcode-select still points at Command Line Tools
swift test --package-path ios
xcodebuild -project ios/PeriMedi.xcodeproj -scheme PeriMedi \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -derivedDataPath ios/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Open `ios/PeriMedi.xcodeproj` in Xcode and Run on an iPhone Simulator (prefer a narrow device such as **iPhone 17e**).

Data stays on device. iCloud (same Apple ID) is the sync path when available. Device-switch notes: [`ios/docs/icloud-device-switch.md`](ios/docs/icloud-device-switch.md).

## Web companion

```bash
npm --prefix web install
npm --prefix web run dev
npm --prefix web test
npm --prefix web run build
```

Root scripts (`npm test`, `npm run build`, `npm run shot:se`, `npm run shot:journey`) delegate to `web/`.

Vercel still deploys the web companion from this repo. The root `vercel.json` installs and builds `web/` and publishes `web/dist`. Alternatively set the Vercel project **Root Directory** to `web`.

Layout screenshots (iPhone SE 375×667) are a **web** check: start Vite, then `npm run shot:se`. The empty-to-tracking journey is `npm run shot:journey` (writes `web/shots/journey-*.png`, gitignored).

## Specs (OpenSpec)

Behavior is defined as capability specs in `openspec/specs/<capability>/spec.md`, including `ios-app` and `ios-persistence`. Agent workflow is in `AGENTS.md`.

```bash
openspec list --specs
openspec validate --specs --strict
```

## Privacy

- iOS: on-device SwiftData; optional Apple iCloud for the same Apple ID
- Web: per browser / device IndexedDB
- Use **More → Backup → Export** to move data (including web → iOS)
- No PeriMedi server, analytics, or required `.env`

## License

Personal project — use and modify freely.
