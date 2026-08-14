# iCloud device-switch check (conditional)

PeriMedi stores domain data in SwiftData. When an Apple ID is signed in and the `iCloud.app.perimedi.ios` container is available, the same store is meant to appear on a second iOS destination.

## Simulator without iCloud

On this machine the Simulator is the required milestone. Unsigned Simulator builds (`CODE_SIGNING_ALLOWED=NO`) have **no CloudKit entitlement**; asking SwiftData for a private CloudKit database SIGTRAPs. The app therefore uses a local-only store unless a signed `embedded.mobileprovision` is present.

**Expected without iCloud:** add a medication, force-quit, relaunch — the row is still there. JSON export/import still moves data. The app must not block on a missing Apple ID.

## When you can verify device switch

1. Add a free or paid Apple ID in Xcode → Settings → Accounts.
2. In the [CloudKit Dashboard](https://icloud.developer.apple.com/) (paid team), create container `iCloud.app.perimedi.ios` if it is not auto-created.
3. Sign **two** destinations into the **same Apple ID** (two Simulators, or Simulator + iPhone) and enable iCloud for PeriMedi if prompted.
4. On destination A: load sample data (or add a uniquely named medication).
5. Wait for a sync (seconds to a few minutes; toggle Airplane Mode off).
6. On destination B: launch PeriMedi — the same medications, schedules, dose logs, remarks, periods, and cycle settings should appear.

If step 6 fails, keep using JSON export from A and import on B. That path is specified independently of iCloud.
