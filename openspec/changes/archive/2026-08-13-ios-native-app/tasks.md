## 1. Toolchain

- [x] 1.1 Switch the active developer directory to Xcode.app (`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`) and confirm `xcodebuild -version` prints Xcode 26.x
- [x] 1.2 Confirm `xcrun simctl list devices available` shows at least one iPhone runtime (prefer the narrowest iPhone, e.g. SE-class)
- [x] 1.3 Add an unpaid Apple ID in Xcode Accounts if none is present (Simulator signing only; no paid team required)

## 2. Repository layout

- [x] 2.1 Move the Vite/React app into `web/` (package.json, src, index.html, public, Vite/Vitest/tsconfig, Playwright scripts) without moving `openspec/` or `ios/`
- [x] 2.2 Point root README/AGENTS and any root npm scripts at `web/` (`npm --prefix web …`) so `npm --prefix web test` and `npm --prefix web run build` still pass
- [x] 2.3 Update `.gitignore` for Xcode (`ios/DerivedData`, `xcuserdata`, `*.xcuserstate`) while keeping `node_modules/` and `dist/` ignored

## 3. iOS project skeleton

- [x] 3.1 Create `ios/PeriMedi` as an iPhone-only SwiftUI app with a SwiftData model container and no `.env` or third-party package requirement
- [x] 3.2 Add TabView destinations Cycle, Month, and More with Cycle as the launch screen
- [x] 3.3 Build and launch on the iOS Simulator (`xcodebuild` + `simctl` or Xcode Run) so the Cycle tab appears without a browser

## 4. Domain and persistence

- [x] 4.1 Port cycle, schedule, therapy-cycle, and dose-range logic from `web/src/lib` into a Swift `PeriMediDomain` module with unit tests for the same core cases
- [x] 4.2 Add SwiftData models for medication, schedule (including therapy cycle / week slots), dose log, remark, period, and cycle settings
- [x] 4.3 Implement a repository that writes/reads those models on device so force-quit + relaunch on the same Simulator keeps data
- [x] 4.4 Implement `ExportPayload` v1 JSON export (share/save file) and import (replace local data); reject invalid files without wiping the store
- [x] 4.5 Implement sample-data load and clear-data with confirmation, matching the web sample’s ~26–29 day periods and default cycle settings after clear
- [x] 4.6 Import a JSON backup exported from the web companion sample and confirm medications, schedules, logs, remarks, periods, and cycle settings match

## 5. iCloud (device switch)

- [x] 5.1 Configure the model container for CloudKit (iCloud capability + container id) so the same schema can sync when an Apple ID is signed in
- [x] 5.2 Keep the app fully usable when the Simulator is not signed into iCloud (local persist only; no blocking error)
- [x] 5.3 Document how to verify the same-Apple-ID restore (second Simulator or later device); run that check if iCloud sign-in is available, otherwise leave it documented as conditional

## 6. Feature parity UI

- [x] 6.1 Port medication + schedule sheet (forms, color, times, exclusive schedule modes, `cycleRule: none`) and persist add/edit
- [x] 6.2 Port Cycle diagram + day context: med lanes, period background, symptom marks, taken/not-taken toggles, jump-to-today, shared selected date
- [x] 6.3 Port Month calendar with the same marks, selected date, and tap-to-select behavior
- [x] 6.4 Port period/cycle-settings and day-note/symptom sheets as closable sheets over the current screen
- [x] 6.5 Port More: language control, export/import, sample, clear, not-medical-advice copy
- [x] 6.6 Keep bottom nav as Cycle / Month / More only; do not add a Today tab

## 7. Localization and layout

- [x] 7.1 Add English and German string catalogs for product chrome; do not translate user-entered fields
- [x] 7.2 Persist language in AppStorage/UserDefaults; default to German when device preferred languages include German
- [x] 7.3 Update chrome immediately on language change and expose the active language to accessibility
- [x] 7.4 Verify Cycle/Month/More and sheet close controls on a narrow iPhone Simulator including safe areas (no whole-screen horizontal pan)

## 8. Verify

- [x] 8.1 Simulator walkthrough: add med, toggle dose, log period + symptom, switch tabs (selected date sticks), load sample, export, clear, re-import
- [x] 8.2 Force-quit and relaunch: data still present; airplane mode: viewing and a new dose/note still work
- [x] 8.3 Run iOS unit tests and `npm --prefix web run build`; run `openspec validate --change ios-native-app --strict` when practical
- [x] 8.4 Update AGENTS.md for `web/` + `ios/` commands, Simulator verification, and the no-PeriMedi-server / iCloud rule

## 9. Visual and layout parity

- [x] 9.1 Capture or reuse web 375 shots of Cycle, Month, More, and the medication / period / symptom sheets (`npm --prefix web run shot:se` with the web app running)
- [x] 9.2 Capture matching iOS Simulator shots of the same screens (narrow iPhone, sample or imported data)
- [x] 9.3 Restyle iOS chrome to the web family: blush/lilac surfaces, PeriMedi wordmark, pill bottom nav, rounded cards
- [x] 9.4 Rebuild Cycle to the web structure: day pager, Today and compact actions, cycle strip with period/symptom marks, sticky med labels, horizontally scrolling multi-day dose bands, selected-day column
- [x] 9.5 Rebuild Month to the web structure: Prev/Today/Next, legend, seven-column grid with cycle-day badges and period/symptom/taken marks, selected outline, control to open the day on Cycle
- [x] 9.6 Restyle More and the three sheets to the web card/row pattern (language pills; backup rows with trailing actions)
- [x] 9.7 Re-shoot web and iOS, read both PNG sets, and fix remaining missing regions or hierarchy mismatches

## 10. Dialog visual parity (fresh web shots)

- [x] 10.1 Start the current web app and capture **new** 375×667 iPhone shots of Cycle, Month, More, and the medication / period / symptom dialogs into `web/shots/` (do not reuse archived `shots/375-se-*`)
- [x] 10.2 Read those fresh PNGs and list the dialog regions (header, close, field groups, palette, schedule modes) that iOS must match
- [x] 10.3 Capture iOS Simulator shots of the same three dialogs
- [x] 10.4 Restyle the iOS medication dialog to the current web inset-card layout
- [x] 10.5 Restyle the iOS period and symptom dialogs the same way
- [x] 10.6 Re-shoot both sides, read the PNGs, and close remaining region or hierarchy gaps

## 11. Empty-to-tracking journey

- [x] 11.1 Clear web data and capture a **new** 375 journey series into `web/shots/journey-*.png` (empty Cycle, period dialog + after save, two or more meds of different forms/schedules, edit, delete, pager prev/next, taken, symptom, Month)
- [x] 11.2 Read those PNGs and confirm the step list used for iOS
- [x] 11.3 Repeat the same journey on the iOS Simulator from empty data and shoot each step
- [x] 11.4 Align empty Cycle, period add, and mixed medication add/edit/delete with the web steps
- [x] 11.5 Align Cycle pager previous/next and taken/not-taken with the web steps
- [x] 11.6 Re-read both shot sets and fix remaining journey mismatches
