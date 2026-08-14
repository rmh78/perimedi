## Why

PeriMedi’s tracking data lives in browser IndexedDB, so it cannot follow the same person onto a new iPhone and is easy to lose when site data is cleared. The product should become an iOS-only companion that keeps the current user’s medications, schedules, doses, periods, and notes on device and restores them after a device switch, without standing up a custom server.

## What Changes

- Ship PeriMedi as a native **iOS app** (SwiftUI) that covers the current Cycle, Month, and More features, including medication/schedule sheets, dose logging, periods, symptoms, localization (en/de), sample data, and backup import/export.
- Make Cycle, Month, More, and the **medication / period / symptom dialogs** look and lay out like the **current** web companion (blush/lilac family, wordmark, pill nav, cycle dose tracks, month legend/grid, inset dialog cards). Not pixel-perfect. Judge by comparing **fresh** web 375×667 screenshots (`web/shots/`, captured from the running app) with iOS Simulator screenshots of the same screens. Do not use archived `shots/375-se-*` files as the oracle.
- Walk the **same empty-to-tracking journey** on web (375) and iOS: start with empty data, add a period, add several medications of different forms and schedule lengths/modes, edit and delete some, use Cycle pager previous/next, mark doses taken, add a symptom, then confirm Month still agrees. Capture a new `web/shots/journey-*.png` series and match iOS step-by-step.
- Store the current user’s domain data in **on-device iOS persistence**, with **Apple iCloud** as the sync path so the same Apple ID restores data on a replacement or second device.
- Keep **JSON backup import/export** (including the existing web export payload) so users can move data from the current SPA and as a fallback when iCloud is unavailable.
- **Repo layout (decision):** stay in this repository. Relocate the existing Vite/React app under `web/` and add a sibling `ios/` Xcode project. Keep `openspec/` at the repo root as the shared product contract.
- **BREAKING (iOS product):** iOS no longer uses IndexedDB or a required web origin. Clearing Safari site data does not apply; uninstall, iCloud sign-out, or an explicit clear-data action does.
- **Not in this change:** Android, a custom backend/account system, App Store submission, push notifications, or HealthKit. Simulator is the required acceptance target; a physical device is optional.

## Capabilities

### New Capabilities

- `ios-app`: Native iOS product shell — Cycle / Month / More, sheets instead of extra pages, same tracking features as today’s SPA, runnable on the iOS Simulator. Visual and layout family resemblance to the current web companion (including dialogs), plus the empty-to-tracking journey, verified by fresh iPhone-width screenshot comparison.
- `ios-persistence`: On-device store for the current user’s domain data, restart survival, Apple ID / iCloud restore on a new or additional device, and JSON import from the web backup format.

### Modified Capabilities

- `privacy-local-data`: Storage is no longer IndexedDB-only. Data stays off any PeriMedi server; iCloud (Apple’s service, user’s Apple ID) is the allowed sync path. Offline use remains required.
- `backup-and-sample`: Export/import must work in iOS (share/files, not a browser download). Web JSON backups remain valid input. Sample and clear-data stay.
- `localization`: Language preference is stored on the device (not `localStorage` / browser profile). Default language follows the device preferred languages when unset.
- `product-constraints`: iOS production quality is an Xcode build/run on Simulator, not only `npm run build`. Sheets remain fully visible and closable. Demo / not-medical-advice stance is unchanged.

## Impact

- New `ios/` SwiftUI app (Xcode 26, iOS 26 SDK already present on this Mac). Domain logic is ported from `web/src/lib/` (cycle, schedule, therapy cycle, dose range, seed), not shared as React UI.
- Existing SPA stays under `web/` as the reference implementation, JSON backup producer, and **visual oracle**. It is not deleted in this change. At apply time, capture **new** 375×667 shots of the running web app — including a scripted `web/shots/journey-*.png` series from empty data — then compare those with iOS Simulator shots. Do not treat older files under repo-root `shots/` as current.
- IndexedDB/Dexie is not used on iOS. Persistence is SwiftData (or Core Data) + CloudKit. No `.env`, no PeriMedi backend, no analytics.
- Developer machine already has Xcode 26.6 and the iOS 26.5 Simulator runtime; the active developer directory must be switched from Command Line Tools to `/Applications/Xcode.app`.
- An unpaid Apple ID is enough to run the Simulator and local persistence. A paid Apple Developer Program membership is needed later for production CloudKit, most physical devices, and App Store — not required to meet the Simulator goal.
