#!/usr/bin/env python3
"""Check the custom-symptom sync model. Exit 1 when an invariant fails."""

from __future__ import annotations

import argparse
import hashlib
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = ROOT / "ios/formal/symptom-sync/SymptomSync.tla"
CFG = ROOT / "ios/formal/symptom-sync/SymptomSync.cfg"
JAR_URL = "https://github.com/tlaplus/tlaplus/releases/download/v1.7.4/tla2tools.jar"
JAR_SHA256 = "936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88"
JAR_CACHE = Path.home() / ".cache/perimedi/tla2tools-1.7.4.jar"

SENTENCES = {
    "LateScoreKept": "A later mark for a removed copy shows on the symptom that remains.",
    "NeverCombinedHides": "A phone that never combined the pair leaves that mark hidden.",
    "WinnerGoneHides": "When the kept symptom is gone, the mark stays hidden.",
    "UniqueMarkRemains": "A mark stored under its own date and id is still on screen after a refresh.",
    "ScoreOnListedSymptom": (
        "A pair saved before the store commits does not hide a mark whose symptom is still listed."
    ),
    "EmptyKeeperSafe": "An empty record id used as the keeper does not remove a mark on another day.",
    "ImportRemembers": "A backup that combined two names stores the pair.",
    "OrphanStaysOut": (
        "A mark the file left out is not brought back by the key that wipe and import keep."
    ),
}

VIOLATED = re.compile(r"Invariant ([A-Za-z_][A-Za-z0-9_]*) is violated")
DISTINCT = re.compile(r"(\d+) distinct states found")


def invariants(text: str) -> list[str]:
    names: list[str] = []
    in_section = False
    for line in text.splitlines():
        stripped = line.strip()
        if not in_section:
            if stripped in {"INVARIANT", "INVARIANTS"}:
                in_section = True
            continue
        if not stripped or (stripped.isupper() and stripped.replace("_", "").isalpha()):
            break
        names.extend(stripped.split())
    return names


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def jar() -> Path:
    if JAR_CACHE.is_file() and sha256(JAR_CACHE) == JAR_SHA256:
        return JAR_CACHE
    JAR_CACHE.parent.mkdir(parents=True, exist_ok=True)
    partial = JAR_CACHE.with_suffix(".partial")
    try:
        urllib.request.urlretrieve(JAR_URL, partial)
    except OSError as err:
        print(f"could not download TLC: {err}", file=sys.stderr)
        raise SystemExit(2) from err
    if sha256(partial) != JAR_SHA256:
        partial.unlink(missing_ok=True)
        print("TLC jar checksum does not match the pin", file=sys.stderr)
        raise SystemExit(2)
    partial.replace(JAR_CACHE)
    return JAR_CACHE


def write_cfg(path: Path, names: list[str]) -> None:
    lines = ["SPECIFICATION Spec", "INVARIANTS", *(f"  {name}" for name in names), ""]
    path.write_text("\n".join(lines), encoding="utf-8")


def run_tlc(java: str, jar_path: Path, names: list[str], work: Path) -> tuple[int, str]:
    # TLC joins -config with the spec directory. An absolute config outside that
    # directory is reported missing. Keep the generated config next to a copy of the spec.
    shutil.copy(SPEC, work / SPEC.name)
    write_cfg(work / "check.cfg", names)
    proc = subprocess.run(
        [
            java,
            "-XX:+UseParallelGC",
            "-jar",
            str(jar_path),
            "-workers",
            "1",
            "-metadir",
            "meta",
            "-config",
            "check.cfg",
            SPEC.name,
        ],
        cwd=work,
        text=True,
        capture_output=True,
        timeout=180,
        check=False,
    )
    return proc.returncode, proc.stdout + proc.stderr


def tail(text: str, lines: int = 40) -> str:
    return "\n".join(text.strip().splitlines()[-lines:])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--warn",
        action="store_true",
        help="Print a GitHub warning for each failed invariant and exit 0.",
    )
    args = parser.parse_args()
    java = shutil.which("java")
    if java is None:
        print("java is not on PATH", file=sys.stderr)
        return 2
    if not SPEC.is_file() or not CFG.is_file():
        print("missing the symptom-sync model", file=sys.stderr)
        return 2
    names = invariants(CFG.read_text(encoding="utf-8"))
    if not names:
        print(f"no invariants in {CFG.relative_to(ROOT)}", file=sys.stderr)
        return 2
    unknown = [name for name in names if name not in SENTENCES]
    if unknown:
        print(f"no sentence for {', '.join(unknown)}", file=sys.stderr)
        return 2

    tool = jar()
    failed: dict[str, str] = {}
    remaining = list(names)
    checked = ""
    with tempfile.TemporaryDirectory(prefix="symptom-sync-") as raw:
        work = Path(raw)
        while remaining:
            try:
                code, output = run_tlc(java, tool, remaining, work)
            except subprocess.TimeoutExpired:
                print("TLC timed out", file=sys.stderr)
                return 2
            if code == 0:
                found = DISTINCT.findall(output)
                if found:
                    checked = found[-1]
                break
            match = VIOLATED.search(output)
            if match is None or match.group(1) not in remaining:
                print(tail(output), file=sys.stderr)
                return 2
            name = match.group(1)
            failed[name] = tail(output)
            remaining.remove(name)

    for name in names:
        status = "FAIL" if name in failed else "PASS"
        print(f"{status} {name}: {SENTENCES[name]}")
    if checked:
        print(f"Checked {checked} states.")
    for name in names:
        if name not in failed:
            continue
        print(f"\n--- {name} ---\n{failed[name]}")
        if args.warn:
            print(f"::warning title=Symptom sync::{name}: {SENTENCES[name]}")
    if failed and not args.warn:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
