# PeriMedi

**Perimenopause medication** companion: track doses, periods, and symptoms.

The product is a **native iOS app** (`ios/`) with on-device SwiftData and optional Apple iCloud sync for the same Apple ID. There is no PeriMedi account, backend, or website.

This is a personal demo, not medical advice.

## Features

- **Cycle / Month / More** via bottom navigation (Cycle is the home screen)
- Medications with form, custom colors, default dose, and integrated schedule
- Schedules: every day, specific weekdays, or cyclic apply/pause — not mixed
- Mark doses taken / not taken
- Cycle day plot, period/symptom marks, month calendar
- Structured 0–4 symptom scores (optional day note)
- **More**: language (EN/DE), dose reminders, and backup (export/import/sample/clear)
- Cycle settings and period history via a sheet

## Layout

```
ios/          Native SwiftUI app + PeriMediDomain package
openspec/     Product specs (`specs/<capability>/spec.md`)
```

## Quick start

See [`ios/README.md`](ios/README.md).

```bash
source ios/env.sh   # if xcode-select still points at Command Line Tools
swift test --package-path ios
xcodebuild -project ios/PeriMedi.xcodeproj -scheme PeriMedi \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -derivedDataPath ios/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Open `ios/PeriMedi.xcodeproj` in Xcode and Run on an iPhone Simulator (prefer a narrow device such as **iPhone 17e**).

Data stays on device. iCloud (same Apple ID) is the sync path when available. Device-switch notes: [`ios/docs/icloud-device-switch.md`](ios/docs/icloud-device-switch.md).

## Specs (OpenSpec)

Behavior is defined as capability specs in `openspec/specs/<capability>/spec.md`. Agent workflow is in `AGENTS.md`.

```bash
openspec list --specs
openspec validate --specs --strict
python3 ios/scripts/check-openspec-sync.py
```

CI job `ids` fails if an active `openspec/changes/<name>/` delta is not yet in `openspec/specs/`. Archive/sync the change in the same PR as the feature.

## Privacy

- On-device SwiftData; optional Apple iCloud for the same Apple ID
- Use **More → Backup → Export** to copy data as JSON
- No PeriMedi server, analytics, or required `.env`

## License

Personal project — use and modify freely.
