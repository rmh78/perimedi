#!/usr/bin/env python3
"""Fail if an active OpenSpec change has delta specs that are not in main specs.

Archive/sync the change (or edit openspec/specs/ directly) before merge.
Ignores openspec/changes/archive/.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHANGES = ROOT / "openspec/changes"
SPECS = ROOT / "openspec/specs"

H2 = re.compile(r"^##\s+(.+?)\s*$", re.M)
REQ = re.compile(r"^### Requirement:\s*(.+?)\s*$", re.M)
SCENARIO = re.compile(r"^#### Scenario:\s*(.+?)\s*$", re.M)
RENAME_FROM = re.compile(r"^\*\*FROM:\*\*\s*(.+?)\s*$", re.M)
RENAME_TO = re.compile(r"^\*\*TO:\*\*\s*(.+?)\s*$", re.M)


def headings(md: str, pattern: re.Pattern[str]) -> list[str]:
    return [m.group(1).strip() for m in pattern.finditer(md)]


def requirement_names(md: str) -> set[str]:
    return set(headings(md, REQ))


def scenarios_under(md: str, requirement: str) -> set[str]:
    names = headings(md, REQ)
    if requirement not in names:
        return set()
    parts = re.split(r"^### Requirement:\s*", md, flags=re.M)
    for part in parts[1:]:
        line, _, rest = part.partition("\n")
        if line.strip() == requirement:
            return set(headings(rest, SCENARIO))
    return set()


def section(md: str, title: str) -> str:
    chunks = re.split(r"^##\s+", md, flags=re.M)
    needle = title.strip().lower()
    for chunk in chunks[1:]:
        line, _, rest = chunk.partition("\n")
        if line.strip().lower() == needle.lower():
            return rest
    return ""


def active_changes() -> list[Path]:
    if not CHANGES.is_dir():
        return []
    return sorted(
        p
        for p in CHANGES.iterdir()
        if p.is_dir() and p.name != "archive" and not p.name.startswith(".")
    )


def main() -> int:
    problems: list[str] = []
    checked = 0

    for change in active_changes():
        spec_root = change / "specs"
        if not spec_root.is_dir():
            continue
        deltas = sorted(spec_root.glob("*/spec.md"))
        if not deltas:
            continue
        for delta_path in deltas:
            capability = delta_path.parent.name
            checked += 1
            delta = delta_path.read_text(encoding="utf-8")
            main_path = SPECS / capability / "spec.md"
            rel_delta = delta_path.relative_to(ROOT).as_posix()
            rel_main = main_path.relative_to(ROOT).as_posix()
            prefix = f"{change.name}/{capability}"

            added = section(delta, "ADDED Requirements")
            modified = section(delta, "MODIFIED Requirements")
            removed = section(delta, "REMOVED Requirements")
            renamed = section(delta, "RENAMED Requirements")

            if not main_path.is_file():
                if requirement_names(added) or requirement_names(modified):
                    problems.append(
                        f"{prefix}: missing {rel_main} (from {rel_delta})"
                    )
                continue

            main_md = main_path.read_text(encoding="utf-8")
            main_reqs = requirement_names(main_md)

            for name in sorted(requirement_names(added)):
                if name not in main_reqs:
                    problems.append(f"{prefix}: ADDED requirement not in main: {name}")
                else:
                    missing = scenarios_under(added, name) - scenarios_under(main_md, name)
                    for sc in sorted(missing):
                        problems.append(
                            f"{prefix}: ADDED scenario {name!r} / {sc!r} not in main"
                        )

            for name in sorted(requirement_names(modified)):
                if name not in main_reqs:
                    problems.append(
                        f"{prefix}: MODIFIED requirement missing from main: {name}"
                    )
                    continue
                missing = scenarios_under(modified, name) - scenarios_under(main_md, name)
                for sc in sorted(missing):
                    problems.append(
                        f"{prefix}: MODIFIED scenario {name!r} / {sc!r} not in main"
                    )

            for name in sorted(requirement_names(removed)):
                if name in main_reqs:
                    problems.append(
                        f"{prefix}: REMOVED requirement still in main: {name}"
                    )

            froms = [m.group(1).strip() for m in RENAME_FROM.finditer(renamed)]
            tos = [m.group(1).strip() for m in RENAME_TO.finditer(renamed)]
            for name in froms:
                if name in main_reqs:
                    problems.append(f"{prefix}: RENAMED FROM still in main: {name}")
            for name in tos:
                if name not in main_reqs:
                    problems.append(f"{prefix}: RENAMED TO missing from main: {name}")

    if problems:
        print(
            "OpenSpec deltas not synced to openspec/specs/ "
            f"({len(problems)} of {checked} change specs):",
            file=sys.stderr,
        )
        for item in problems:
            print(f"  {item}", file=sys.stderr)
        print(
            "Archive/sync the change (or copy the requirements into "
            "openspec/specs/) in this PR.",
            file=sys.stderr,
        )
        return 1

    if checked == 0:
        print("ok: no active OpenSpec changes")
    else:
        print(f"ok: {checked} OpenSpec change specs synced to openspec/specs/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
