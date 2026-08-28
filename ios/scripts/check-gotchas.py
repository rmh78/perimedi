#!/usr/bin/env python3
"""Fail if the agent gotchas file is missing or over its line budget."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / ".grok/gotchas.md"
BUDGET = 40
MARKER = "Line budget: 40"


def main() -> int:
    if not PATH.is_file():
        print("missing .grok/gotchas.md", file=sys.stderr)
        return 2
    text = PATH.read_text(encoding="utf-8")
    if MARKER not in text:
        print(".grok/gotchas.md must declare `Line budget: 40`", file=sys.stderr)
        return 1
    n = len(text.splitlines())
    if n > BUDGET:
        print(
            f".grok/gotchas.md is {n} lines (budget {BUDGET}). Drop a stale gotcha.",
            file=sys.stderr,
        )
        return 1
    print(f"ok: gotchas {n}/{BUDGET} lines")
    return 0


if __name__ == "__main__":
    sys.exit(main())
