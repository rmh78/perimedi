#!/usr/bin/env python3
"""Fail when a tracked path has a docs directory outside docs/app-store."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from agent_rails import docs_folder_problems

ROOT = Path(__file__).resolve().parents[2]


def tracked_paths() -> list[str]:
    out = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    return [name for name in out.decode("utf-8").split("\0") if name]


def main(_argv: list[str] | None = None) -> int:
    problems = docs_folder_problems(tracked_paths())
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        return 1
    print("ok: no docs folder outside docs/app-store")
    return 0


if __name__ == "__main__":
    sys.exit(main())
