#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
# shellcheck disable=SC1091
source "$ROOT/ios/env.sh"
PHASE="${1:-before}"
DIR="${DIALOG_SHOTS_DIR:-/tmp/dialog-buttons/$PHASE}"
if [[ "$PHASE" == "corrected" ]]; then
  PASSES="${DIALOG_SHOTS_PASSES:-en-light,de-light}"
  TEST="testWriteCorrectedDialogFooters"
else
  PASSES="${DIALOG_SHOTS_PASSES:-en-light,de-light,en-dark}"
  TEST="testWriteDialogFooters"
fi
UDID="$(xcrun simctl list devices | sed -n 's/.*iPhone 17e (\([^)]*\)).*/\1/p' | head -n 1)"
if [[ -z "$UDID" ]]; then
  echo "dialog-footer-shots: iPhone 17e not installed" >&2
  exit 1
fi
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
PLIST="$HOME/Library/Preferences/com.apple.iphonesimulator.plist"
if [[ -f "$PLIST" ]]; then
  /usr/libexec/PlistBuddy -c "Set :DevicePreferences:${UDID}:ConnectHardwareKeyboard false" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :DevicePreferences:${UDID}:ConnectHardwareKeyboard bool false" "$PLIST" 2>/dev/null \
    || true
fi
xcrun simctl shutdown "$UDID" 2>/dev/null || true
xcrun simctl boot "$UDID"
mkdir -p "$DIR" ios/DerivedData
# xcodebuild forwards TEST_RUNNER_* from its environment and strips the prefix.
# A build setting with that name does not arrive. The unprefixed names are the
# ones the test reads when the prefix is stripped.
export DIALOG_SHOTS=1
export DIALOG_SHOTS_DIR="$DIR"
export DIALOG_SHOTS_PASSES="$PASSES"
export TEST_RUNNER_DIALOG_SHOTS=1
export TEST_RUNNER_DIALOG_SHOTS_DIR="$DIR"
export TEST_RUNNER_DIALOG_SHOTS_PASSES="$PASSES"
LOG="ios/DerivedData/dialog-footer-shots-${PHASE}.log"
set +e
xcodebuild test \
  -project ios/PeriMedi.xcodeproj \
  -scheme PeriMedi \
  -destination "platform=iOS Simulator,id=${UDID}" \
  -derivedDataPath ios/DerivedData \
  -only-testing:PeriMediUITests/DialogFooterShotTests/${TEST} \
  -collect-test-diagnostics never \
  CODE_SIGNING_ALLOWED=NO \
  TEST_RUNNER_DIALOG_SHOTS=1 \
  TEST_RUNNER_DIALOG_SHOTS_DIR="$DIR" \
  TEST_RUNNER_DIALOG_SHOTS_PASSES="$PASSES" \
  2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
set -e
if grep -F "$TEST" "$LOG" | grep -q "skipped"; then
  echo "dialog-footer-shots: skipped; DIALOG_SHOTS did not reach the test" >&2
  exit 1
fi
if ! grep -F "$TEST" "$LOG" | grep -q "passed"; then
  echo "dialog-footer-shots: did not pass" >&2
  exit 1
fi
exit "$status"
