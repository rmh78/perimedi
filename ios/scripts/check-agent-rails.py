#!/usr/bin/env python3
"""Fail when a wired script or runner literal is absent from Agents.md."""

from __future__ import annotations

import sys
from pathlib import Path

from agent_rails import missing_script_names, read_agents

ROOT = Path(__file__).resolve().parents[2]
RUNNERS = (
    ROOT / ".github/workflows/ci.yml",
    ROOT / ".grok/skills/verify-perimedi/scripts/control-perimedi",
)


def main() -> int:
    try:
        agents = read_agents(ROOT)
    except FileNotFoundError as err:
        print(f"missing {err}", file=sys.stderr)
        return 1
    missing = [path for path in RUNNERS if not path.is_file()]
    if missing:
        for path in missing:
            print(f"missing {path.relative_to(ROOT)}", file=sys.stderr)
        return 1
    runner = "\n".join(path.read_text(encoding="utf-8") for path in RUNNERS)
    problems = missing_script_names(runner, agents)
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        return 1
    print("ok: wired scripts named in Agents.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
