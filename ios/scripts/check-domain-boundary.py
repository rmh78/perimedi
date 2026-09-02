#!/usr/bin/env python3
"""Fail if the app reimplements domain schedule/cycle math or writes dose logs."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOMAIN = ROOT / "ios/Sources/PeriMediDomain"
APP = ROOT / "ios/PeriMedi"
PERSISTENCE = APP / "Persistence"
STORE = PERSISTENCE / "Store.swift"

MATH_FILES = (
    "CycleLogic.swift",
    "ScheduleLogic.swift",
    "TherapyCycleLogic.swift",
    "DoseRangeLogic.swift",
    "EffectLogic.swift",
    "MedicationChangeLog.swift",
)

NEEDLES = (
    "ScheduleLogic.expandPlannedDoses",
    "CycleLogic.cycleWindowForDate",
    "DoseRangeLogic.doseExpansionRange",
    "EffectLogic.summarize",
    "MedicationChangeLog.events",
    "MedicationChangeLog.hasChanges",
)

PUBLIC_STATIC_FUNC = re.compile(r"public\s+static\s+func\s+(\w+)\b")
SET_DOSE_STATUS_DEF = re.compile(r"func\s+setDoseStatus\b")


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def collect_math_names() -> tuple[list[str], list[str]]:
    missing: list[str] = []
    names: list[str] = []
    seen: set[str] = set()
    for filename in MATH_FILES:
        path = DOMAIN / filename
        if not path.is_file():
            missing.append(rel(path))
            continue
        for name in PUBLIC_STATIC_FUNC.findall(path.read_text(encoding="utf-8")):
            if name not in seen:
                seen.add(name)
                names.append(name)
    return names, missing


def app_swift_files() -> list[Path]:
    return sorted(p for p in APP.rglob("*.swift") if p.is_file())


def is_under_persistence(path: Path) -> bool:
    try:
        path.resolve().relative_to(PERSISTENCE.resolve())
        return True
    except ValueError:
        return False


def check_reimplemented(names: list[str], files: list[Path]) -> list[str]:
    patterns = [
        (name, re.compile(rf"(?:static\s+)?func\s+{re.escape(name)}\b"))
        for name in names
    ]
    hits: list[str] = []
    for path in files:
        for i, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for _name, pat in patterns:
                if pat.search(line) and "private" not in line.split("func", 1)[0]:
                    hits.append(f"{rel(path)}:{i}: {line.strip()}")
                    break
    return hits


def missing_needles(files: list[Path]) -> list[str]:
    corpus = "\n".join(p.read_text(encoding="utf-8") for p in files)
    return [needle for needle in NEEDLES if needle not in corpus]


def check_sddoselog(files: list[Path]) -> list[str]:
    hits: list[str] = []
    for path in files:
        if is_under_persistence(path):
            continue
        for i, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if "SDDoseLog" in line:
                hits.append(f"{rel(path)}:{i}: {line.strip()}")
    return hits


def check_set_dose_status(files: list[Path]) -> list[str]:
    store = rel(STORE)
    hits: list[str] = []
    for path in files:
        for i, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if SET_DOSE_STATUS_DEF.search(line) and rel(path) != store:
                hits.append(f"{rel(path)}:{i}: {line.strip()}")
    return hits


def main() -> int:
    if not DOMAIN.is_dir():
        print(f"missing {DOMAIN.relative_to(ROOT).as_posix()}", file=sys.stderr)
        return 2
    if not APP.is_dir():
        print(f"missing {APP.relative_to(ROOT).as_posix()}", file=sys.stderr)
        return 2

    names, missing_math = collect_math_names()
    if missing_math:
        for path in missing_math:
            print(f"missing {path}", file=sys.stderr)
        return 2

    if not STORE.is_file():
        print(f"missing {rel(STORE)}", file=sys.stderr)
        return 2

    files = app_swift_files()
    if not files:
        print(f"missing {APP.relative_to(ROOT).as_posix()} Swift sources", file=sys.stderr)
        return 2

    violations: list[str] = []
    violations.extend(check_reimplemented(names, files))
    needles = missing_needles(files)
    violations.extend(check_sddoselog(files))
    violations.extend(check_set_dose_status(files))

    failed = False
    if needles:
        print(
            "app must keep calling domain schedule/cycle math; missing: "
            + ", ".join(needles),
            file=sys.stderr,
        )
        failed = True
    for item in violations:
        print(item, file=sys.stderr)
        failed = True

    if failed:
        return 1

    print("ok: domain owns schedule/cycle/effect math; persistence is the only dose-log writer")
    return 0


if __name__ == "__main__":
    sys.exit(main())
