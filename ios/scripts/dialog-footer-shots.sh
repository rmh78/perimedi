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
# control-perimedi drive runs xcodebuild. That process copies TEST_RUNNER_*
# into the test and strips the prefix. The test reads the stripped names.
export DIALOG_SHOTS=1
export DIALOG_SHOTS_DIR="$DIR"
export DIALOG_SHOTS_PASSES="$PASSES"
export TEST_RUNNER_DIALOG_SHOTS=1
export TEST_RUNNER_DIALOG_SHOTS_DIR="$DIR"
export TEST_RUNNER_DIALOG_SHOTS_PASSES="$PASSES"
mkdir -p "$DIR"
DRIVER="$ROOT/.grok/skills/verify-perimedi/scripts/control-perimedi"
RUN_ID="dialog-footer-shots-${PHASE}"
SLOT="PeriMediUITests-DialogFooterShotTests-${TEST}"
LOG="$ROOT/.grok/skills/verify-perimedi/evidence/${RUN_ID}/${SLOT}/xcodebuild.log"
cleanup() {
  "$DRIVER" --run-id "$RUN_ID" cleanup || true
}
trap cleanup EXIT
"$DRIVER" --run-id "$RUN_ID" launch
set +e
"$DRIVER" --run-id "$RUN_ID" drive --test "PeriMediUITests/DialogFooterShotTests/${TEST}"
status=$?
set -e
if [[ -f "$LOG" ]] && grep -F "$TEST" "$LOG" | grep -q "skipped"; then
  echo "dialog-footer-shots: skipped; DIALOG_SHOTS did not reach the test" >&2
  exit 1
fi
if [[ "$status" -ne 0 ]]; then
  exit "$status"
fi
if [[ ! -f "$LOG" ]] || ! grep -F "$TEST" "$LOG" | grep -q "passed"; then
  echo "dialog-footer-shots: did not pass" >&2
  exit 1
fi
exit 0
