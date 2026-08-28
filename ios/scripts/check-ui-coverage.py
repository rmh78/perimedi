#!/usr/bin/env python3
"""Report feature-map surfaces that UI tests never drive.

Advisory by default (exit 0). Pass --fail-uncovered to exit 1 on gaps.

A surface is covered if a distinctive A11yID from its features/*.md
appears in ios/PeriMediUITests/. Only backtick strings that also exist
in ios/PeriMedi/App/A11yID.swift count (so L10n keys and file names
are ignored). Shared chrome does not count: tab.*, sheet.close,
date.done, time.done, confirm.*. Templates like cycle.lane.{slug}
match any test string with that prefix. A file with no distinctive
IDs is blocked (cannot be driven), not uncovered.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
A11Y = ROOT / "ios/PeriMedi/App/A11yID.swift"
FEATURES = ROOT / ".grok/skills/verify-perimedi/features"
UITESTS = ROOT / "ios/PeriMediUITests"

INTERP_NESTED = re.compile(r"\\\([^()]*\([^()]*\)[^()]*\)")
INTERP_SIMPLE = re.compile(r"\\\([^()]*\)")
BRACE = re.compile(r"\{[^}]+\}")
FILE_EXT = {".md", ".sh", ".swift", ".json", ".py", ".txt", ".png"}

SKIP_EXACT = {
    "sheet.close",
    "date.done",
    "time.done",
    "confirm.delete",
    "confirm.cancel",
    "confirm.action",
}


def normalize(s: str) -> str:
    s = INTERP_NESTED.sub("{var}", s)
    s = INTERP_SIMPLE.sub("{var}", s)
    s = BRACE.sub("{var}", s)
    return s


def a11y_needles(swift: str) -> set[str]:
    out: set[str] = set()
    for lit in re.findall(r'"([^"]*)"', swift):
        if "." not in lit:
            continue
        out.add(normalize(lit))
    return out


def backtick_candidates(markdown: str) -> list[str]:
    found: list[str] = []
    seen: set[str] = set()
    for body in re.findall(r"`([^`]+)`", markdown):
        body = body.strip()
        if "." not in body or "/" in body or "(" in body:
            continue
        suffix = Path(body).suffix.lower()
        if suffix in FILE_EXT:
            continue
        if body in seen:
            continue
        seen.add(body)
        found.append(body)
    return found


def distinctive(ids: list[str], allowed: set[str]) -> list[str]:
    out: list[str] = []
    for item in ids:
        if item.startswith("tab."):
            continue
        if item in SKIP_EXACT:
            continue
        if normalize(item) not in allowed:
            continue
        out.append(item)
    return out


def matches(needle: str, corpus: str) -> bool:
    if BRACE.search(needle) or "{var}" in needle:
        prefix = BRACE.split(needle, maxsplit=1)[0]
        prefix = prefix.split("{var}", 1)[0]
        return bool(prefix) and prefix in corpus
    return needle in corpus


def classify(path: Path, corpus: str, allowed: set[str]) -> tuple[str, list[str]]:
    ids = distinctive(backtick_candidates(path.read_text(encoding="utf-8")), allowed)
    if not ids:
        return "blocked", []
    missing = [item for item in ids if not matches(item, corpus)]
    if len(missing) == len(ids):
        return "uncovered", ids
    return "covered", [item for item in ids if item not in missing]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--fail-uncovered",
        action="store_true",
        help="exit 1 when a surface with IDs is never driven (default: advisory)",
    )
    args = parser.parse_args()

    for required in (A11Y, FEATURES, UITESTS):
        if not required.exists():
            print(f"missing {required.relative_to(ROOT)}", file=sys.stderr)
            return 2

    allowed = a11y_needles(A11Y.read_text(encoding="utf-8"))
    corpus = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted(UITESTS.glob("*.swift"))
    )

    rows: list[tuple[str, str, list[str]]] = []
    for path in sorted(FEATURES.glob("*.md")):
        if path.name.lower() == "readme.md":
            continue
        status, detail = classify(path, corpus, allowed)
        rows.append((status, path.stem, detail))

    covered = [name for status, name, _ in rows if status == "covered"]
    uncovered = [(name, detail) for status, name, detail in rows if status == "uncovered"]
    blocked = [name for status, name, _ in rows if status == "blocked"]

    for status, name, detail in rows:
        extra = ""
        if status == "uncovered":
            extra = f"  ({', '.join(detail)})"
        elif status == "blocked":
            extra = "  (no driveable IDs)"
        print(f"{status:10} {name}{extra}")

    print(
        f"ui-coverage: {len(covered)} covered, "
        f"{len(uncovered)} uncovered, {len(blocked)} blocked"
        f"{' (advisory)' if not args.fail_uncovered else ''}"
    )
    if uncovered and not args.fail_uncovered:
        print(
            "uncovered surfaces are advisory until journeys exist "
            "(More/backup: see issues #2).",
            file=sys.stderr,
        )

    if args.fail_uncovered and uncovered:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
