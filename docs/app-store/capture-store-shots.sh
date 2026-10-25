#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

SLOTS='
6.9|iPhone 18 Pro Max|0|screenshots|1320x2868+1290x2796
6.3|iPhone 17 Pro|1|screenshots-6.3|1206x2622
'

FRAME_FILES=(
  01-cycle.png
  02-trends.png
  03-symptoms.png
  04-visit.png
  05-month.png
  06-more.png
)

slot_row() {
  local want="$1"
  local line row_id device create directory frames extra pipes
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pipes="${line//[^|]/}"
    if [[ "${#pipes}" -ne 4 ]]; then
      echo "capture-store-shots: bad row" >&2
      return 1
    fi
    IFS='|' read -r row_id device create directory frames extra <<<"$line"
    if [[ -n "$extra" ]]; then
      echo "capture-store-shots: bad row" >&2
      return 1
    fi
    [[ "$row_id" == "$want" ]] || continue
    if [[ "$directory" == "screenshots" && "$row_id" != "6.9" ]]; then
      echo "capture-store-shots: screenshots directory is only the 6.9 row" >&2
      return 1
    fi
    if [[ "$create" != "0" && "$create" != "1" ]]; then
      echo "capture-store-shots: bad create flag" >&2
      return 1
    fi
    if [[ -z "$device" || -z "$directory" || "$directory" == "." || "$directory" == ".." || "$directory" == *"/"* ]]; then
      echo "capture-store-shots: bad directory" >&2
      return 1
    fi
    if [[ ! "$frames" =~ ^[0-9]+x[0-9]+([+][0-9]+x[0-9]+)*$ ]]; then
      echo "capture-store-shots: bad frames" >&2
      return 1
    fi
    printf '%s\n' "$row_id" "$device" "$create" "$directory" "$frames"
    return 0
  done <<<"$SLOTS"
  echo "capture-store-shots: unknown slot ${want}" >&2
  return 1
}

resolve_udid() {
  python3 - "$1" "$2" <<'PY'
import json, subprocess, sys

name = sys.argv[1]
create = sys.argv[2] == "1"

def version_key(text):
    numbers = []
    current = ""
    for ch in text:
        if ch.isdigit():
            current += ch
        elif current:
            numbers.append(int(current))
            current = ""
    if current:
        numbers.append(int(current))
    return tuple(numbers)

def load(args):
    return json.loads(subprocess.check_output(args))

devices = load(["xcrun", "simctl", "list", "devices", "available", "-j"])
found = []
for runtime, entries in devices.get("devices", {}).items():
    for device in entries:
        if device.get("name") != name:
            continue
        if device.get("isAvailable", True) is False:
            continue
        udid = device.get("udid")
        if not udid:
            continue
        found.append((runtime, device))

booted = [item for item in found if item[1].get("state") == "Booted"]
pool = booted or found
if pool:
    pool.sort(key=lambda item: version_key(item[0]), reverse=True)
    print(pool[0][1]["udid"])
    sys.exit(0)

if not create:
    print(f"missing simulator named {name}", file=sys.stderr)
    sys.exit(1)

runtimes = load(["xcrun", "simctl", "list", "runtimes", "available", "-j"])
ios_runtimes = []
for runtime in runtimes.get("runtimes", []):
    if runtime.get("isAvailable", True) is False:
        continue
    identifier = runtime.get("identifier", "")
    runtime_name = runtime.get("name", "")
    if ".iOS-" not in identifier and not runtime_name.startswith("iOS"):
        continue
    types = runtime.get("supportedDeviceTypes") or []
    if types and not any(item.get("name") == name for item in types):
        continue
    ios_runtimes.append(runtime)

if not ios_runtimes:
    print(f"no available iOS runtime for {name}", file=sys.stderr)
    sys.exit(1)

ios_runtimes.sort(
    key=lambda runtime: version_key(runtime.get("version") or runtime.get("identifier", "")),
    reverse=True,
)
runtime = ios_runtimes[0]
runtime_id = runtime.get("identifier")
if not runtime_id:
    print(f"no runtime identifier for {name}", file=sys.stderr)
    sys.exit(1)

dev_id = None
for item in (runtime.get("supportedDeviceTypes") or []):
    if item.get("name") == name and item.get("identifier"):
        dev_id = item["identifier"]
        break
if not dev_id:
    listed = load(["xcrun", "simctl", "list", "devicetypes", "-j"])
    for item in listed.get("devicetypes", []):
        if item.get("name") == name and item.get("identifier"):
            dev_id = item["identifier"]
            break
if not dev_id:
    print(f"missing device type {name}", file=sys.stderr)
    sys.exit(1)

try:
    created = subprocess.check_output(
        ["xcrun", "simctl", "create", name, dev_id, runtime_id],
        text=True,
    )
except subprocess.CalledProcessError:
    print(f"could not create {name}", file=sys.stderr)
    sys.exit(1)
lines = [line.strip() for line in created.splitlines() if line.strip()]
if len(lines) != 1:
    print(f"unexpected simctl create output for {name}", file=sys.stderr)
    sys.exit(1)
print(lines[0])
PY
}

prepare_simulator() {
  local udid="$1"
  local state status_pid
  state="$(xcrun simctl list devices | grep "$udid" | head -n 1 || true)"
  if [[ "$state" != *Booted* ]]; then
    xcrun simctl boot "$udid"
  fi
  xcrun simctl bootstatus "$udid" -b

  xcrun simctl status_bar "$udid" override \
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
}

run_writer() {
  local udid="$1"
  local directory="$2"
  local frames="$3"
  local log status
  export STORE_SHOTS=1
  export STORE_DIR="$directory"
  export STORE_FRAME="$frames"
  # The test reads the shell environment. The xcodebuild settings below do not arrive there.
  export TEST_RUNNER_STORE_SHOTS=1
  export TEST_RUNNER_STORE_DIR="$directory"
  export TEST_RUNNER_STORE_FRAME="$frames"
  mkdir -p ios/DerivedData
  log="ios/DerivedData/store-shots.log"
  set +e
  xcodebuild test \
    -project ios/PeriMedi.xcodeproj \
    -scheme PeriMedi \
    -destination "platform=iOS Simulator,id=${udid}" \
    -derivedDataPath ios/DerivedData \
    -only-testing:PeriMediUITests/StoreScreenshotTests/testWriteStoreScreenshots \
    CODE_SIGNING_ALLOWED=NO \
    TEST_RUNNER_STORE_SHOTS=1 \
    TEST_RUNNER_STORE_DIR="${directory}" \
    TEST_RUNNER_STORE_FRAME="${frames}" \
    2>&1 | tee "$log"
  status=${PIPESTATUS[0]}
  set -e
  if grep -F "testWriteStoreScreenshots" "$log" | grep -q "skipped"; then
    echo "capture skipped; STORE_SHOTS did not reach the test" >&2
    return 1
  fi
  if ! grep -F "testWriteStoreScreenshots" "$log" | grep -q "passed"; then
    echo "capture did not pass" >&2
    return 1
  fi
  if [[ "$status" -ne 0 ]]; then
    return "$status"
  fi
}

check_frames() {
  python3 - "$1" "$2" "${FRAME_FILES[@]}" <<'PY'
import subprocess, sys
from pathlib import Path

directory = sys.argv[1]
frames = sys.argv[2]
files = sys.argv[3:]
accepted = set()
for token in frames.split("+"):
    width_text, height_text = token.split("x")
    accepted.add((int(width_text), int(height_text)))
ok = True
for locale in ("en", "de"):
    for name in files:
        path = Path("docs/app-store") / directory / locale / name
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
}

if [[ $# -gt 1 ]]; then
  echo "capture-store-shots: extra arguments" >&2
  exit 1
fi

slot_id="${1:-6.9}"
row="$(slot_row "$slot_id")" || exit 1
{
  IFS= read -r row_id
  IFS= read -r device
  IFS= read -r create
  IFS= read -r directory
  IFS= read -r frames
} <<<"$row"
if [[ "$row_id" != "$slot_id" ]]; then
  echo "capture-store-shots: bad row" >&2
  exit 1
fi

# shellcheck disable=SC1091
source ios/env.sh

udid="$(resolve_udid "$device" "$create")" || exit 1
if [[ -z "$udid" ]]; then
  echo "capture-store-shots: missing simulator named ${device}" >&2
  exit 1
fi
prepare_simulator "$udid"
run_writer "$udid" "$directory" "$frames"
check_frames "$directory" "$frames"
python3 docs/app-store/check-listing.py
