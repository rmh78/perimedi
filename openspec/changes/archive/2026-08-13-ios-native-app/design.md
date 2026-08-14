## Context

See `proposal.md` for motivation. Today PeriMedi is a client-only React 19 + Vite SPA with Dexie/IndexedDB (`perimedi`) and OpenSpec capabilities under `openspec/specs/`. Domain logic lives in `src/lib/` (cycle, schedule, therapy cycle, dose range, seed) and the interchange format is `ExportPayload` version 1 in `src/types.ts`.

This Mac already has macOS 26.5, Xcode 26.6 at `/Applications/Xcode.app`, the iOS 26.5 Simulator runtime, and Swift 6.2. The active developer directory is still Command Line Tools (`/Library/Developer/CommandLineTools`), so `xcodebuild`/`simctl` fail until that is switched. Hardware is Apple M1 / 8 GB RAM — tight for Xcode + Simulator, but sufficient for an iPhone SE-class Simulator.

## Goals / Non-Goals

**Goals:**

- A native iOS app that meets the delta specs on the Simulator: feature parity, on-device persistence, JSON import from the web export, iCloud-ready data model.
- Layout and visual family match the **current** web companion (same regions and hierarchy on Cycle, Month, More, and the three dialogs), judged by **fresh** 375 screenshot comparison — not pixel-identical.
- The same **empty-to-tracking journey** works on iOS as on the current web companion, verified by a paired `journey-*.png` series.
- One repository that keeps the web companion as a reference while the iOS app becomes the product.
- A documented, minimal toolchain path that this machine can follow without a paid Apple Developer account for the Simulator milestone.

**Non-Goals:**

- Pixel-identical Swift recreation of every Tailwind detail (exact font metrics, 1px borders, or identical shadow blur).
- Sharing React components or Dexie inside the iOS target.
- Production CloudKit entitlements, TestFlight, or App Store in this change.
- Android, HealthKit, notifications, or a PeriMedi backend.

## Decisions

### 1. Stay in this repo: `web/` + `ios/` (not a new repository)

**Choice:** Relocate the current Vite app to `web/` (so `package.json`, `src/`, `index.html`, Vite/Vitest configs move together). Add `ios/` as an Xcode project (`PeriMedi.xcodeproj` or a Swift Package + `PeriMediApp`). Keep `openspec/`, `AGENTS.md`, and `.gitignore` at the repo root.

**Why this over a new repo**

- OpenSpec, seed data, and the JSON schema are already here. A second repo would fork the product contract immediately.
- The web app is the behavioral oracle during the port (export a backup, import on iOS, compare Cycle/Month).
- One history for the migration. Split later if App Store signing or access control needs isolation.

**Why this over “drop iOS files next to current `src/`”**

- Mixing Xcode and Vite at the root will collide (`src/`, `public/`, scripts, CI). Sibling roots keep each toolchain obvious.

**Why not delete the web app now**

- It is the fastest way to produce a known-good `ExportPayload` and to keep `npm test` coverage of schedule/cycle math until Swift tests exist.

Root after the move:

```
web/                 # existing SPA (paths in package.json stay relative to web/)
ios/                 # Xcode project + Swift sources
openspec/            # shared product specs
AGENTS.md
```

Web commands become `npm --prefix web run dev` / `build` / `test`, or a tiny root script that delegates.

### 2. Native SwiftUI rewrite — not Capacitor, not React Native

**Choice:** SwiftUI app, iPhone-only (iPhone SE-class Simulator as the layout bar). TabView: Cycle / Month / More. Sheets for medication+schedule, period/cycle settings, day notes. Port `src/lib/` into a small Swift module (`PeriMediDomain`) with unit tests.

**Alternatives**

| Option | Time to “looks like today” | iOS persistence + device switch | Advice |
| --- | --- | --- | --- |
| **SwiftUI + SwiftData + CloudKit** | Longer (UI rewrite) | First-class, no PeriMedi server | **Recommended.** Matches “iOS-only” and “iOS persistence.” |
| Capacitor around the current SPA | Fastest visual parity | IndexedDB still local-to-WebView; iCloud would need a custom native bridge and a new sync protocol | Use only if the goal were “wrap the website.” It does not solve device switch cleanly. |
| React Native / Expo | Medium | Need a native module or a backend for iCloud | Shares TypeScript, but you still rewrite navigation/sheets and you do not get CloudKit for free. Extra JS runtime on 8 GB RAM. |

A hybrid wrap would keep the privacy/IndexedDB problem the proposal exists to leave behind.

### 2b. Visual oracle: fresh web 375 shots vs Simulator shots (still SwiftUI)

**Choice:** Keep a native SwiftUI UI. At apply time, start the **current** web companion and capture **new** 375×667 PNGs into `web/shots/` (Cycle, Month, More, add/edit medication, period settings, symptoms). Those files — not archived repo-root `shots/375-se-*` — are the visual oracle. Then capture the same screens on the iOS Simulator and **read both PNG sets**.

**Why not wrap the web app for looks**

- Capacitor would copy pixels but would not give SwiftData/CloudKit. Visual parity is a SwiftUI restyle, not a WebView.

**What “more or less the same” means**

- Same regions in the same order (wordmark, pager, cycle strip + sticky med lanes + scrolling dose bands, month legend + marked grid, More language then backup rows).
- Dialogs: inset rounded panel, circular close, title (medication dialog includes a form icon), sectioned fields, two-row color palette, exclusive Every day / Specific days / Cyclic modes.
- Same blush/lilac family, form icons, blood-drop and symptom marks, pill bottom nav.
- Allowed: system fonts, safe-area padding, slightly different corner radii.

Implement iOS dialogs as custom SwiftUI sheet chrome that follows that pattern — not a stock gray `Form` as the primary look.

### 2c. Scripted empty-to-tracking journey

**Choice:** One script used on both platforms. At apply time, clear web data and capture **new** 375 shots into `web/shots/`:

1. `journey-01-empty.png` — Cycle with no data  
2. `journey-02-period-dialog.png` / `journey-03-period-saved.png` — add period, then Cycle after save  
3. `journey-04-med-everyday.png` — add a daily pill (or similar)  
4. `journey-05-med-dated-or-cyclic.png` — add a second med of another form and another schedule style  
5. `journey-06-edited.png` — edit one med  
6. `journey-07-deleted.png` — delete the other  
7. `journey-08-pager-prev.png` / `journey-09-pager-next.png` — Cycle previous, then next  
8. `journey-10-taken.png` — mark remaining planned dose taken  
9. `journey-11-symptom.png` — add a symptom  
10. `journey-12-month.png` — Month with the resulting marks  

Then repeat the same steps on the iOS Simulator (empty store first) and compare each pair. Fix iOS where the outcome or major regions diverge. Do not use archived `shots/375-se-*` or a sample-data shortcut as the journey oracle.

### 3. Persistence: SwiftData locally, CloudKit for device switch

**Choice:** SwiftData models mirroring `Medication`, `Schedule` (+ `TherapyCycle` / week slots), `DoseLog`, `Remark`, `Period`, `CycleSettings`. Enable CloudKit on the model container when an iCloud capability is present. Language preference is `AppStorage` / `UserDefaults` (not part of the clinical payload).

JSON import/export stays the portable contract (`ExportPayload` v1). Import replaces local domain tables, same as today’s More → Backup.

**Why SwiftData over Core Data or SQLite+GRDB**

- Less boilerplate for this schema size.
- CloudKit sync is the Apple-supported path (`ModelConfiguration` + iCloud container) without writing a server.
- Core Data + `NSPersistentCloudKitContainer` is the fallback if SwiftData+CloudKit hits a schema limit (relationships, unique constraints). Same conceptual model.

**Why not a custom backend**

- Violates `privacy-local-data` and is unnecessary for a single-user Apple ID.

**Simulator vs device switch**

- **Required for this change:** local SwiftData survives force-quit/reboot on one Simulator.
- **Implemented, conditionally verified:** CloudKit sync. The iOS Simulator *can* sign into iCloud (Settings → Apple ID), but it is flaky and often needs a paid team + iCloud container for a real container. Acceptance without a signed-in Simulator is: local persist + JSON import/export. Device-switch scenario is verified when two destinations share an Apple ID (two Simulators, or Simulator + device later).

Do not block the Simulator milestone on CloudKit actually merging in the Simulator.

### 4. Developer prerequisites — use what is already installed

**Minimum to hit the Simulator goal (this machine):**

1. **macOS** — already 26.5.
2. **Xcode 26.6** — already at `/Applications/Xcode.app` with iPhone Simulator SDK 26.5 and runtime `iOS 26.5`.
3. **Switch the active developer directory** (one-time, needs admin):

   `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`

   Then accept the license if prompted: `sudo xcodebuild -license accept`.
4. **Unpaid Apple ID** inside Xcode (Settings → Accounts) — enough for Simulator signing with a personal team.
5. **Xcode command-line:** `xcodebuild -scheme PeriMedi -destination 'platform=iOS Simulator,name=iPhone SE (or closest available)' build` and `xcrun simctl` for launch.

**Not required for Simulator feature work**

- Apple Developer Program ($99/year). Needed later for: reliable physical-device install, production iCloud container, TestFlight, App Store.
- A second Mac, CI Mac, or Fastlane.
- CocoaPods / SPM third-party stack. Prefer Foundation + SwiftData + SwiftUI only. If a calendar helper is needed, port `date-fns` usage; do not add a heavy date library.

**Optional later**

- Paid team + iCloud capability + CloudKit dashboard to verify device switch for real.
- A physical iPhone (better CloudKit than Simulator).
- More RAM. 8 GB will swap; close browsers while Xcode indexes. Prefer one Simulator, not two at once, until CloudKit testing needs a pair.

**If Xcode were missing** (not the case here): install from the Mac App Store (~10+ GB). Command Line Tools alone cannot build an iOS app or open Simulator.

### 5. App structure

```
ios/PeriMedi/
  App/                 # @main, TabView, locale
  Domain/              # pure schedule/cycle/dose/seed (ported)
  Persistence/         # SwiftData models, repository, JSON import/export
  Features/
    Cycle/
    Month/
    More/
    Sheets/
  Resources/           # en.lproj / de.lproj, med icons
```

Read path: `@Query` / repository → views. Write path: repository methods (add med+schedule, toggle dose, upsert period/remark, import payload, load seed, clear). Domain functions stay side-effect free so they can be tested without a store.

Port schedule exclusivity and `cycleRule: none` as in the web app. Seed dataset is a Swift transcription of `src/lib/seed.ts`, not a live read of the TS file.

i18n: String Catalogs (`Localizable.xcstrings`) with the same key roles as `web/src/i18n/messages/{en,de}.ts`. More screen still owns the language control.

### 6. Web companion after the move

Keep it buildable. Update `AGENTS.md` paths. Playwright `shot:se` is the **web** half of visual comparison. iOS visual check is Simulator screenshots (not Playwright). Read both sets before claiming layout is good. Do not introduce a server or Vercel dependency for iOS.

## Risks / Trade-offs

- **[CloudKit in Simulator is unreliable]** → Treat local persist + JSON as the Simulator bar. Wire CloudKit so a later paid team / device can enable it without a schema rewrite. Document the two-Simulator Apple ID steps; do not fail the change if Apple’s Simulator iCloud is down.
- **[Rewrite cost / missed edge cases]** → Port `src/lib` tests to Swift first; import a web-exported sample backup and walk Cycle / Month / More as the integration check.
- **[8 GB RAM]** → One Simulator, iPhone SE or iPhone 16, release-unoptimized but avoid extra destinations. Quit Chrome/Playwright while compiling.
- **[xcode-select still on CLT]** → First implementation task; nothing else in `ios/` will build until this is fixed.
- **[SwiftData unique keys vs CloudKit]** → Avoid uniqueness constraints that CloudKit rejects; identify dose logs by id + `plannedFor` in code.
- **[Visual drift from the blush/lilac web UI]** → Reuse raster icons from `web/public/med-icons` and `ui-icons`. After restyle, re-shoot web 375 and iOS Simulator and close remaining region/hierarchy gaps. Pixel-perfect is not required.
- **[Monorepo path churn]** → Update README, AGENTS, Vite/Playwright working directories in the same change as the `web/` move so the reference app does not rot.

## Migration Plan

1. Switch `xcode-select` to Xcode.app; confirm `xcodebuild -version` and `xcrun simctl list devices`.
2. Move the SPA to `web/`; fix scripts and docs; confirm `npm --prefix web test` and `npm --prefix web run build`.
3. Create `ios/PeriMedi` Xcode project (iOS App, SwiftUI, SwiftData). Empty Cycle tab launching on Simulator.
4. Port domain + SwiftData models + JSON import/export + seed.
5. Port screens and sheets until tracking scenarios pass on Simulator.
6. Add iCloud capability and CloudKit configuration (sync works when signed in; app still works when not).
7. Verify: force-quit persistence, import `ExportPayload` from web sample, en/de, sheets, offline (airplane mode on Simulator).
8. Visual pass: capture **fresh** web 375 shots into `web/shots/` (screens + three dialogs), capture matching iOS Simulator shots, read both sets; restyle until the major regions match. Never use archived `shots/375-se-*` as the oracle.
9. Journey pass: capture `web/shots/journey-*.png` from empty data, repeat on iOS, align any mismatched step.

Rollback: the web companion in `web/` remains the previous product. Deleting `ios/` returns to a web-only tree. No production users or App Store build exist yet.

## Open Questions

- Exact Simulator device name available after `xcode-select` switch (SE vs “iPhone 16e” etc.) — pick the narrowest installed iPhone runtime; does not change specs.
- Bundle identifier (e.g. `app.perimedi.ios`) and CloudKit container id — chosen at project creation; not user-visible.
