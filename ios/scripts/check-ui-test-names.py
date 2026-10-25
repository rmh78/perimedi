#!/usr/bin/env python3
"""Fail when a UI test method is absent from Agents.md and features/."""

from __future__ import annotations

import sys
from pathlib import Path

from agent_rails import read_agents, unnamed_ui_tests

ROOT = Path(__file__).resolve().parents[2]
SWIFT_DIR = ROOT / "ios/PeriMediUITests"
FEATURE_DIR = ROOT / ".grok/skills/verify-perimedi/features"


def main() -> int:
    if not SWIFT_DIR.is_dir():
        print(f"missing {SWIFT_DIR.relative_to(ROOT)}", file=sys.stderr)
        return 1
    try:
        docs = [read_agents(ROOT)]
    except FileNotFoundError as err:
        print(f"missing {err}", file=sys.stderr)
        return 1
    if FEATURE_DIR.is_dir():
        docs.extend(
            path.read_text(encoding="utf-8")
            for path in sorted(FEATURE_DIR.glob("*.md"))
        )
    swift = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted(SWIFT_DIR.rglob("*.swift"))
    )
    problems = unnamed_ui_tests(swift, "\n".join(docs))
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        return 1
    print("ok: ui test methods are named")
    return 0


if __name__ == "__main__":
    sys.exit(main())
