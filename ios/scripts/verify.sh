#!/usr/bin/env bash
# Doctor: prove PeriMedi is healthy for agent work.
# Needs macOS, Xcode, and an iPhone 17e Simulator (not iPhone 17).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/ios/env.sh"

DEVICE_NAME="iPhone 17e"
BUNDLE="app.perimedi.ios"
PROJECT="$ROOT/ios/PeriMedi.xcodeproj"
DERIVED="$ROOT/ios/DerivedData"

step() { printf '\n==> %s\n' "$*"; }
fail() { printf 'verify: %s\n' "$*" >&2; exit 1; }

step "feature map"
python3 "$ROOT/ios/scripts/check-feature-map.py"

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "domain and UI tests need macOS with Xcode and an iPhone 17e Simulator"
fi

step "domain tests"
swift test --package-path "$ROOT/ios"

step "simulator ($DEVICE_NAME)"
UDID="${SIM_UDID:-}"
if [[ -z "$UDID" ]]; then
  UDID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone 17e/ {print $2; exit}')"
fi
if [[ -z "$UDID" ]]; then
  echo "Available iPhone simulators:" >&2
  xcrun simctl list devices available | grep -E 'iPhone' >&2 || true
  fail "no iPhone 17e Simulator found. Create one in Xcode (Window → Devices and Simulators). Do not use iPhone 17."
fi

DEVICE_LINE="$(xcrun simctl list devices | grep "$UDID" | head -n 1 || true)"
if ! grep -q 'iPhone 17e' <<<"$DEVICE_LINE"; then
  fail "simulator $UDID is not iPhone 17e: $DEVICE_LINE"
fi

echo "Using $DEVICE_NAME ($UDID)"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b

step "uninstall leftover PeriMedi"
xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true

step "UI tests"
xcodebuild test \
  -project "$PROJECT" \
  -scheme PeriMedi \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO

step "uninstall after pass"
xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true

printf '\nverify: ok\n'
