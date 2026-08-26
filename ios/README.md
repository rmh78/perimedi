# PeriMedi iOS

Native SwiftUI app. Domain logic lives in the `PeriMediDomain` Swift package; the app target adds SwiftData + CloudKit and the Cycle / Month / More UI.

## Prerequisites

- macOS with **Xcode 26** at `/Applications/Xcode.app`
- iOS Simulator runtime (iPhone; prefer the narrowest device, e.g. iPhone 17e)

If `xcode-select -p` still prints Command Line Tools:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Without sudo, prefix commands with the env file:

```bash
source ios/env.sh
```

An unpaid Apple ID in Xcode → Settings → Accounts is enough for Simulator signing. This project also builds the Simulator destination **unsigned** (`CODE_SIGNING_ALLOWED=NO`) so a missing Apple ID does not block local work.

A **paid Apple Developer Program** membership is not required for the Simulator milestone. It is required later for a production iCloud container, most physical devices, TestFlight, and the App Store.

## Build and run (Simulator)

```bash
source ios/env.sh
# Domain tests (no Simulator)
swift test --package-path ios

# App
xcodebuild \
  -project ios/PeriMedi.xcodeproj \
  -scheme PeriMedi \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -derivedDataPath ios/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Open `ios/PeriMedi.xcodeproj` in Xcode and Run on **iPhone 17e** (or the narrowest iPhone listed).

## Run on a physical iPhone

A free Apple ID is enough for **your** phone (the app expires after about 7 days; Run again to refresh). TestFlight / other people’s phones need a paid Apple Developer Program membership.

1. On the iPhone: **Settings → Privacy & Security → Developer Mode** → On, then restart. Xcode reports `Developer Mode disabled` until this is on.
2. Unlock the phone, plug it in, tap **Trust**.
3. Open `ios/PeriMedi.xcodeproj`, select destination **iPhone Harald** (or your device), press Run.
4. First launch: **Settings → General → VPN & Device Management** → trust your Apple ID if iOS asks.

The app target uses Automatic signing with the Personal Team already in the project. Do **not** add the iCloud capability on a free team — Xcode will fail to provision. Data stays in on-device SwiftData; use More → Export / Import to copy from the Simulator.

Simulator CLI builds can still pass `CODE_SIGNING_ALLOWED=NO`.

## UI tests (interaction proof)

Instrumented XCUITests live in `PeriMediUITests/`. There is a first-use journey (empty home → log a period → add medications → mark taken → symptom → Month) and a dose-reminder journey (add a pending med, take it from the reminder card). Tests start empty, pin English and today (`2026-03-15`), and tap Cycle / sheets. Watch **iPhone 17e** (Simulator → Window → iPhone 17e). **iPhone 17** is a different Simulator and will stay idle.

```bash
source ios/env.sh
xcodebuild test \
  -project ios/PeriMedi.xcodeproj \
  -scheme PeriMedi \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -derivedDataPath ios/DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

Launch contract used by the suite: `-en -clear -today=2026-03-15 -uiTesting`. `-uiTesting` turns off UIView animations so XCTest is not blocked on springs. The reminder test also passes `-remindIn=4` so the next pending slot appears as a tappable in-app card (system banners are not asserted). Do not pass `-journeyStep` or `-loadSample` for these tests.

`JourneyScript` and `scripts/shot-journey.sh` only seed the store and take screenshots for visual review. They are not the interaction proof.

## Persistence

- On-device **SwiftData**. Survives force-quit and Simulator reboot.
- **CloudKit** (`iCloud.app.perimedi.ios`) is configured so the same Apple ID can restore data on another device. If iCloud is unavailable (typical on an unsigned Simulator), the store falls back to local-only and the app stays usable.
- JSON export/import uses `ExportPayload` version 1.

See [docs/icloud-device-switch.md](docs/icloud-device-switch.md) for the conditional two-destination check.
