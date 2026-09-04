# iCloud device-switch check (conditional)

PeriMedi stores domain data in SwiftData. When an Apple ID is signed in and the `iCloud.app.perimedi.ios` container is available, the same store is meant to appear on a second iOS destination.

## How the UI stays in sync

`Store` is a snapshot `ObservableObject`. Cycle and Month read `store.snapshot`, not SwiftData `@Query`.

- After a **local** save, `Store` writes with `#Predicate` / fetch-by-id, then `refresh()`es the snapshot once.
- When **CloudKit** is on, `Store` also observes Core Data remote-change and CloudKit import events (`NSPersistentStoreRemoteChange`, `NSPersistentCloudKitContainer` import/setup) and `refresh()`es after a short debounce.
- Returning to the foreground (`willEnterForeground`) `refresh()`es `Store` as well as dose reminders. Destination B does not need a local write to show data that arrived from A. Remote-change observers cover the case where B stays in the foreground.
- `DoseReminderCenter` still uses `store.afterChange`; that callback runs when a refresh actually changes the snapshot, including remote imports.

One published `StoreSnapshot` means one SwiftUI invalidation per refresh.

## Simulator without iCloud

On this machine the Simulator is the required milestone. Unsigned Simulator builds (`CODE_SIGNING_ALLOWED=NO`, including `verify.sh`) have **no CloudKit entitlement**; asking SwiftData for a private CloudKit database SIGTRAPs. The app therefore uses a local-only store unless the process is entitled for `iCloud.app.perimedi.ios`.

Device builds put that container in `embedded.mobileprovision`. Signed Simulator builds usually have **no** provision file; CloudKit is still enabled when the process entitlements include the container (Xcode “Sign to Run Locally” Simulated.xcent, or a development identity + `PeriMedi.entitlements`).

`CODE_SIGN_ENTITLEMENTS` points at `PeriMedi/Resources/PeriMedi.entitlements` (CloudKit + container only). `DEVELOPMENT_TEAM` is `7H4A6PWSPS`, overridable with `PERIMEDI_DEVELOPMENT_TEAM` when regenerating the project. Do not add the iCloud capability on a free Personal Team.

**Expected without iCloud:** add a medication, force-quit, relaunch — the row is still there. JSON export/import still moves data. The app must not block on a missing Apple ID.

## Signed Simulator pair (local device-switch)

`verify.sh` cannot do this (it forces unsigned). From the repo root:

```bash
bash ios/scripts/setup-signed-icloud-sims.sh
```

That boots **iPhone 17e** (A) and **iPhone 17** (B), uninstalls leftover PeriMedi, builds with team `7H4A6PWSPS` (no `CODE_SIGNING_ALLOWED=NO`), stamps CloudKit entitlements, and installs+launches on both.

Then you still sign **each** Simulator into the **same Apple ID** (Settings → Apple Account / iCloud). The script cannot do that. Create container `iCloud.app.perimedi.ios` in the CloudKit Dashboard (Development) if it is missing.

## Nested schedule blobs (last-write-wins)

Schedule fields `daysOfWeekJSON`, `timesJSON`, `therapyJSON`, and `weekPatternJSON` are opaque JSON strings in SwiftData / CloudKit. A conflict on those attributes is **last-write-wins on the whole blob**, not a field-level merge. Do not flatten them into related models without a schema migration.

## When you can verify device switch

1. Add a paid Apple ID in Xcode → Settings → Accounts (paid team already enrolled; a free Personal Team cannot enable iCloud).
2. In the [CloudKit Dashboard](https://icloud.developer.apple.com/) (paid team), create container `iCloud.app.perimedi.ios` if it is not auto-created.
3. Sign **two** destinations into the **same Apple ID** (two Simulators, or Simulator + iPhone) and enable iCloud for PeriMedi if prompted.
4. On destination A: load sample data (or add a uniquely named medication).
5. Wait for a sync (seconds to a few minutes; toggle Airplane Mode off).
6. On destination B — **already running, returning from background, or freshly launched** — the same medications, schedules, dose logs, remarks, symptom scores, periods, and cycle settings should appear without a local write on B.

If step 6 fails, keep using JSON export from A and import on B. That path is specified independently of iCloud. Invalid import files leave existing data unchanged.

## Persistence failures

A failed local save rolls back the in-memory context, does not publish a snapshot that disagrees with disk, and shows a short error (EN/DE). JSON export remains the fallback when iCloud is off.
