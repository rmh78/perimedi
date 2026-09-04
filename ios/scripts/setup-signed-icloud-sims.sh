#!/usr/bin/env bash
# Signed Simulator pair for iCloud device-switch. Not used by CI / verify.sh.
# Does not sign the Simulators into iCloud — do that in Settings on each.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
# shellcheck disable=SC1091
source ios/env.sh

A_NAME="${SIM_DEVICE_A:-iPhone 17e}"
B_NAME="${SIM_DEVICE_B:-iPhone 17}"
TEAM="${PERIMEDI_DEVELOPMENT_TEAM:-7H4A6PWSPS}"
BUNDLE="app.perimedi.ios"
CONTAINER="iCloud.app.perimedi.ios"
DERIVED="ios/DerivedData-signed"
APP="$DERIVED/Build/Products/Debug-iphonesimulator/PeriMedi.app"

udid_for() {
  xcrun simctl list devices available | awk -v name="$1" '
    $0 ~ name " \\(" {
      if (match($0, /\([A-F0-9-]{36}\)/)) {
        print substr($0, RSTART+1, RLENGTH-2)
        exit
      }
    }'
}

A_UDID="$(udid_for "$A_NAME")"
B_UDID="$(udid_for "$B_NAME")"
if [[ -z "$A_UDID" || -z "$B_UDID" ]]; then
  echo "missing Simulator: A=$A_NAME ($A_UDID) B=$B_NAME ($B_UDID)" >&2
  xcrun simctl list devices available | grep iPhone | head
  exit 1
fi
if [[ "$A_UDID" == "$B_UDID" ]]; then
  echo "A and B resolved to the same UDID; pick different SIM_DEVICE_A / SIM_DEVICE_B" >&2
  exit 1
fi

echo "==> boot $A_NAME ($A_UDID) and $B_NAME ($B_UDID)"
open -a Simulator
xcrun simctl boot "$A_UDID" 2>/dev/null || true
xcrun simctl boot "$B_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$A_UDID" -b
xcrun simctl bootstatus "$B_UDID" -b

echo "==> uninstall leftover $BUNDLE"
xcrun simctl uninstall "$A_UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl uninstall "$B_UDID" "$BUNDLE" 2>/dev/null || true

echo "==> signed build (team $TEAM, no CODE_SIGNING_ALLOWED=NO)"
xcodebuild \
  -project ios/PeriMedi.xcodeproj \
  -scheme PeriMedi \
  -destination "platform=iOS Simulator,name=$A_NAME" \
  -derivedDataPath "$DERIVED" \
  DEVELOPMENT_TEAM="$TEAM" \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates \
  build

if [[ ! -d "$APP" ]]; then
  echo "missing $APP" >&2
  exit 1
fi

echo "==> entitlement check"
# Simulator uses "Sign to Run Locally" plus Simulated.xcent in the main executable.
# Do not re-sign with an Apple Development identity — that is denied at launch.
if strings "$APP/PeriMedi" | grep -q "com.apple.developer.icloud-container-identifiers"; then
  echo "ok: Simulator entitlements blob includes CloudKit container keys"
else
  echo "warn: main executable has no CloudKit entitlement blob (Store may stay local)" >&2
fi
if [[ -f "$APP/embedded.mobileprovision" ]] && grep -q "$CONTAINER" "$APP/embedded.mobileprovision"; then
  echo "ok: embedded.mobileprovision includes $CONTAINER"
else
  echo "note: no CloudKit mobileprovision (normal on Simulator)"
fi

echo "==> install + launch"
xcrun simctl install "$A_UDID" "$APP"
xcrun simctl install "$B_UDID" "$APP"
xcrun simctl launch "$A_UDID" "$BUNDLE"
xcrun simctl launch "$B_UDID" "$BUNDLE"

cat <<EOF

Signed PeriMedi is on:
  A  $A_NAME  $A_UDID
  B  $B_NAME  $B_UDID

You still need to do (I cannot use your Apple ID password):
  1. CloudKit Dashboard: container $CONTAINER exists (Development env).
  2. On EACH Simulator: Settings → sign in with the SAME Apple ID → iCloud on.
  3. On A: More → Load sample (or add a unique med).
  4. Wait, then check B (already running or after returning to foreground).

JSON export/import remains the fallback if Simulator iCloud sign-in fails.
EOF
