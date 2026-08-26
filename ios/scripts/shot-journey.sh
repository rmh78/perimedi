#!/bin/zsh
# Capture optional iOS Simulator journey shots (seeded store, not the UI-test proof).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/ios/env.sh"

UDID="${SIM_UDID:-}"
if [[ -z "$UDID" ]]; then
  UDID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone 17e/ {print $2; exit}')"
fi
if [[ -z "$UDID" ]]; then
  echo "No iPhone 17e Simulator found" >&2
  exit 1
fi

OUT="$ROOT/ios/shots"
mkdir -p "$OUT"

APP="$ROOT/ios/DerivedData/Build/Products/Debug-iphonesimulator/PeriMedi.app"
BUNDLE="app.perimedi.ios"

echo "Building PeriMedi for Simulator $UDID"
xcodebuild \
  -project "$ROOT/ios/PeriMedi.xcodeproj" \
  -scheme PeriMedi \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$ROOT/ios/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  build

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"

NAMES=(
  "01-empty"
  "02-period-dialog"
  "03-period-saved"
  "04-med-everyday"
  "05-med-dated-or-cyclic"
  "06-edited"
  "07-deleted"
  "08-pager-prev"
  "09-pager-next"
  "10-taken"
  "11-symptom"
  "12-month"
)

for i in {1..12}; do
  name="${NAMES[$i]}"
  echo "Launching journey step $i ($name)"
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE" -en "-journeyStep=$i"
  # First launch and sheets need extra settle time
  if [[ "$i" -eq 1 || "$i" -eq 2 ]]; then
    sleep 6
  else
    sleep 4
  fi
  xcrun simctl io "$UDID" screenshot "$OUT/journey-$name.png"
  echo "  wrote ios/shots/journey-$name.png"
done

echo "Done. Review ios/shots/journey-*.png"
