#!/usr/bin/env bash
# Doctor: prove PeriMedi is healthy for agent work.
# Needs macOS, Xcode, and an iPhone Simulator.
# Prefers iPhone 17e, then iPhone 17 (GitHub macos-latest always has 17).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/ios/env.sh"

PREFERRED_DEVICE="${SIM_DEVICE:-iPhone 17e}"
BUNDLE="app.perimedi.ios"
PROJECT="$ROOT/ios/PeriMedi.xcodeproj"
DERIVED="$ROOT/ios/DerivedData"

step() { printf '\n==> %s\n' "$*"; }
fail() { printf 'verify: %s\n' "$*" >&2; exit 1; }

# simctl list: "    iPhone 17e (UUID) (Shutdown)" — match "Name (" so
# "iPhone 17" does not steal 17e / 17 Pro.
udid_named() {
  local name="$1"
  xcrun simctl list devices available | awk -F '[()]' -v n="$name (" 'index($0, n) {print $2; exit}'
}

step "feature map"
python3 "$ROOT/ios/scripts/check-feature-map.py"

step "feature layout"
python3 "$ROOT/ios/scripts/check-feature-layout.py"

step "domain boundary"
python3 "$ROOT/ios/scripts/check-domain-boundary.py"

step "UI test coverage"
python3 "$ROOT/ios/scripts/check-ui-coverage.py" --fail-uncovered

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "domain and UI tests need macOS with Xcode and an iPhone Simulator"
fi

# Domain has its own CI job. Skip the duplicate on GitHub.
if [[ -z "${GITHUB_ACTIONS:-}" ]]; then
  step "domain tests"
  swift test --package-path "$ROOT/ios"
fi

step "simulator"
UDID="${SIM_UDID:-}"
if [[ -n "$UDID" ]]; then
  DEVICE_LINE="$(xcrun simctl list devices | grep "$UDID" | head -n 1 || true)"
  [[ -n "$DEVICE_LINE" ]] || fail "SIM_UDID $UDID is not a known simulator"
else
  UDID="$(udid_named "$PREFERRED_DEVICE")"
  if [[ -z "$UDID" && "$PREFERRED_DEVICE" != "iPhone 17e" ]]; then
    UDID="$(udid_named "iPhone 17e")"
  fi
  if [[ -z "$UDID" ]]; then
    UDID="$(udid_named "iPhone 17")"
  fi
  if [[ -z "$UDID" ]]; then
    echo "Preferred simulators missing. Available iPhones:" >&2
    xcrun simctl list devices available | grep -E 'iPhone' >&2 || true
    UDID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone / {print $2; exit}')"
  fi
  [[ -n "$UDID" ]] || fail "no iPhone Simulator found"
  DEVICE_LINE="$(xcrun simctl list devices | grep "$UDID" | head -n 1 || true)"
fi

echo "Using $DEVICE_LINE"
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
