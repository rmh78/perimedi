#!/usr/bin/env python3
"""Fail when covered Swift changes and the symptom-sync model stays put."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / ".grok/skills/check-symptom-sync/SKILL.md"
MODEL = (
    "ios/formal/symptom-sync/SymptomSync.tla",
    "ios/formal/symptom-sync/SymptomSync.cfg",
)
_SWIFT = re.compile(r"`([^`\n]+\.swift)`")
_SYNC = re.compile(r"Sync commit:\s*`([0-9a-f]{7,40})`")


def covered_swift(skill: str) -> list[str]:
    start = skill.find("## Covered code")
    if start < 0:
        return []
    rest = skill[start:]
    end = rest.find("\n## ", 1)
    body = rest if end < 0 else rest[:end]
    found: list[str] = []
    for match in _SWIFT.finditer(body):
        path = match.group(1)
        if path not in found:
            found.append(path)
    return found


def sync_commit(skill: str) -> str | None:
    match = _SYNC.search(skill)
    return match.group(1) if match else None


def _problem(path: str) -> str:
    return (
        f"{path}: update ios/formal/symptom-sync/SymptomSync.tla, "
        "ios/formal/symptom-sync/SymptomSync.cfg, or the Sync commit in "
        ".grok/skills/check-symptom-sync/SKILL.md."
    )


def drift_problems(
    changed: list[str],
    covered: list[str],
    sync_before: str | None,
    sync_after: str | None,
) -> list[str]:
    hit = [path for path in covered if path in changed]
    if not hit or any(path in changed for path in MODEL) or sync_before != sync_after:
        return []
    return [_problem(path) for path in hit]


def changed_names(base: str) -> list[str]:
    proc = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=ACMRD", f"{base}...HEAD"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "git diff failed")
    return [line for line in proc.stdout.splitlines() if line]


def skill_at(rev: str) -> str | None:
    rel = SKILL.relative_to(ROOT).as_posix()
    proc = subprocess.run(
        ["git", "show", f"{rev}:{rel}"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        return None
    return proc.stdout


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="origin/main")
    args = parser.parse_args()
    try:
        changed = changed_names(args.base)
        before = skill_at(args.base)
    except RuntimeError as err:
        print(err, file=sys.stderr)
        return 2
    if not SKILL.is_file():
        print(f"missing {SKILL.relative_to(ROOT)}", file=sys.stderr)
        return 2
    head = SKILL.read_text(encoding="utf-8")
    covered = covered_swift(head)
    after = sync_commit(head)
    if not covered or after is None:
        print(
            "check-symptom-sync skill is missing covered Swift paths or the Sync commit.",
            file=sys.stderr,
        )
        return 2
    problems = drift_problems(
        changed,
        covered,
        sync_commit(before) if before else None,
        after,
    )
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        return 1
    print("ok: symptom-sync model matches covered Swift")
    return 0


if __name__ == "__main__":
    sys.exit(main())
