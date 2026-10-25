#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
# shellcheck disable=SC1091
source ios/env.sh

export STORE_SHOTS=1
export TEST_RUNNER_STORE_SHOTS=1

UDID="$(
  python3 - <<'PY'
import json, subprocess, sys
raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
data = json.loads(raw)
found = []
for devices in data.get("devices", {}).values():
    for device in devices:
        if device.get("name") == "iPhone 18 Pro Max" and device.get("isAvailable", True):
            found.append(device)
if not found:
    print("missing simulator named iPhone 18 Pro Max", file=sys.stderr)
    sys.exit(1)
booted = [device for device in found if device.get("state") == "Booted"]
chosen = booted[0] if booted else found[0]
print(chosen["udid"])
PY
)"

STATE="$(xcrun simctl list devices | grep "$UDID" | head -n 1 || true)"
if [[ "$STATE" != *Booted* ]]; then
  xcrun simctl boot "$UDID"
fi
xcrun simctl bootstatus "$UDID" -b

xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 \
  --dataNetwork wifi &
status_pid=$!
for _ in 1 2 3 4 5; do
  if ! kill -0 "$status_pid" 2>/dev/null; then
    wait "$status_pid" 2>/dev/null || echo "capture-store-shots: status_bar override failed" >&2
    status_pid=""
    break
  fi
  sleep 1
done
if [[ -n "${status_pid}" ]] && kill -0 "$status_pid" 2>/dev/null; then
  kill -TERM "$status_pid" 2>/dev/null || true
  wait "$status_pid" 2>/dev/null || true
  echo "capture-store-shots: status_bar override bounded" >&2
fi

mkdir -p ios/DerivedData
LOG="ios/DerivedData/store-shots.log"
set +e
xcodebuild test \
  -project ios/PeriMedi.xcodeproj \
  -scheme PeriMedi \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' \
  -derivedDataPath ios/DerivedData \
  -only-testing:PeriMediUITests/StoreScreenshotTests/testWriteStoreScreenshots \
  CODE_SIGNING_ALLOWED=NO \
  TEST_RUNNER_STORE_SHOTS=1 \
  2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
set -e

if grep -F "testWriteStoreScreenshots" "$LOG" | grep -q "skipped"; then
  echo "capture skipped; STORE_SHOTS did not reach the test" >&2
  exit 1
fi
if ! grep -F "testWriteStoreScreenshots" "$LOG" | grep -q "passed"; then
  echo "capture did not pass" >&2
  exit 1
fi
if [[ "$status" -ne 0 ]]; then
  exit "$status"
fi

python3 - <<'PY'
import subprocess, sys
from pathlib import Path

files = [
    "01-cycle.png",
    "02-trends.png",
    "03-symptoms.png",
    "04-visit.png",
    "05-month.png",
    "06-more.png",
]
accepted = {(1320, 2868), (1290, 2796)}
ok = True
for locale in ("en", "de"):
    for name in files:
        path = Path("docs/app-store/screenshots") / locale / name
        if not path.is_file():
            print(f"missing {path}", file=sys.stderr)
            ok = False
            continue
        out = subprocess.check_output(
            ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)],
            text=True,
        )
        print(out, end="" if out.endswith("\n") else "\n")
        width = height = None
        for line in out.splitlines():
            if "pixelWidth" in line:
                width = int(line.split(":")[-1].strip())
            if "pixelHeight" in line:
                height = int(line.split(":")[-1].strip())
        if (width, height) not in accepted:
            print(f"bad size {path} {width}x{height}", file=sys.stderr)
            ok = False
if not ok:
    sys.exit(1)
PY

python3 docs/app-store/check-listing.py
