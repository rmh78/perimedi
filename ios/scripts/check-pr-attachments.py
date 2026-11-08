#!/usr/bin/env python3
"""Fail for a docs path outside docs/app-store, or a user-attachment link in committed markdown."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from agent_rails import tracked_doc_problems

ROOT = Path(__file__).resolve().parents[2]


def tracked_paths() -> list[str]:
    out = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    return [name for name in out.decode("utf-8").split("\0") if name]


def markdown_by_path(paths: list[str]) -> dict[str, str]:
    return {
        name: (ROOT / name).read_text(encoding="utf-8")
        for name in paths
        if name.endswith(".md")
    }


def main(_argv: list[str] | None = None) -> int:
    paths = tracked_paths()
    problems = tracked_doc_problems(paths, markdown_by_path(paths))
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        return 1
    print(
        "ok: no docs folder outside docs/app-store "
        "and no user-attachment link in committed markdown"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
