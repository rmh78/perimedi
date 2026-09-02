#!/usr/bin/env bash
# Doctor: prove PeriMedi is healthy for agent work.
# Needs macOS, Xcode, and an iPhone Simulator.
# Prefers iPhone 17e, then iPhone 17 locally. GitHub CI pins 17e (STRICT_SIM).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/ios/env.sh"

PREFERRED_DEVICE="${SIM_DEVICE:-iPhone 17e}"
PREFERRED_OS="${SIM_OS:-}"
BUNDLE="app.perimedi.ios"
PROJECT="$ROOT/ios/PeriMedi.xcodeproj"
DERIVED="$ROOT/ios/DerivedData"
RESULT="$DERIVED/PeriMedi.xcresult"

step() { printf '\n==> %s\n' "$*"; }
fail() { printf 'verify: %s\n' "$*" >&2; exit 1; }

# simctl list: "    iPhone 17e (UUID) (Shutdown)" — match "Name (" so
# "iPhone 17" does not steal 17e / 17 Pro.
# Optional second arg is a runtime like "26.5" (matches "-- iOS 26.5 --").
udid_named() {
  local name="$1"
  local os="${2:-}"
  if [[ -n "$os" ]]; then
    xcrun simctl list devices available | awk -F '[()]' -v n="$name (" -v os="$os" '
      $0 ~ "^-- iOS " os " " {p=1; next}
      /^-- / {p=0}
      p && index($0, n) {print $2; exit}
    '
  else
    xcrun simctl list devices available | awk -F '[()]' -v n="$name (" 'index($0, n) {print $2; exit}'
  fi
}

# The `ids` job already ran these on GitHub.
if [[ -z "${GITHUB_ACTIONS:-}" ]]; then
  step "feature map"
  python3 "$ROOT/ios/scripts/check-feature-map.py"

  step "feature layout"
  python3 "$ROOT/ios/scripts/check-feature-layout.py"

  step "domain boundary"
  python3 "$ROOT/ios/scripts/check-domain-boundary.py"

  step "OpenSpec sync"
  python3 "$ROOT/ios/scripts/check-openspec-sync.py"

  step "UI test coverage"
  python3 "$ROOT/ios/scripts/check-ui-coverage.py" --fail-uncovered
fi

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
  UDID="$(udid_named "$PREFERRED_DEVICE" "$PREFERRED_OS")"
  STRICT=0
  if [[ -n "${GITHUB_ACTIONS:-}" || "${STRICT_SIM:-}" == "1" ]]; then
    STRICT=1
  fi
  if [[ -z "$UDID" && "$STRICT" -eq 0 ]]; then
    if [[ "$PREFERRED_DEVICE" != "iPhone 17e" ]]; then
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
  fi
  if [[ -z "$UDID" ]]; then
    echo "Required simulator missing: ${PREFERRED_DEVICE}${PREFERRED_OS:+ (iOS $PREFERRED_OS)}. Available iPhones:" >&2
    xcrun simctl list devices available | grep -E 'iPhone' >&2 || true
    fail "required simulator '${PREFERRED_DEVICE}' not found"
  fi
  DEVICE_LINE="$(xcrun simctl list devices | grep "$UDID" | head -n 1 || true)"
fi

echo "Using $DEVICE_LINE"
# typeText uses the software keyboard. Simulator Connect Hardware Keyboard
# eats characters (Apple Forums / FB9148288). The flag is read at boot.
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
PLIST="$HOME/Library/Preferences/com.apple.iphonesimulator.plist"
if [[ -f "$PLIST" ]]; then
  /usr/libexec/PlistBuddy -c "Set :DevicePreferences:${UDID}:ConnectHardwareKeyboard false" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :DevicePreferences:${UDID}:ConnectHardwareKeyboard bool false" "$PLIST" 2>/dev/null \
    || true
fi
xcrun simctl shutdown "$UDID" 2>/dev/null || true
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b

step "uninstall leftover PeriMedi"
xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true

step "UI tests"
rm -rf "$RESULT"
set +e
xcodebuild test \
  -project "$PROJECT" \
  -scheme PeriMedi \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED" \
  -resultBundlePath "$RESULT" \
  CODE_SIGNING_ALLOWED=NO
status=$?
set -e
if [[ "$status" -ne 0 ]]; then
  if [[ -d "$RESULT" ]]; then
    step "xcresult summary"
    xcrun xcresulttool get test-results summary --path "$RESULT" \
      || xcrun xcresulttool get test-results tests --path "$RESULT" \
      || true
  fi
  fail "xcodebuild test exited $status"
fi

step "uninstall after pass"
xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null || true

printf '\nverify: ok\n'
