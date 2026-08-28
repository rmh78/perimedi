#!/usr/bin/env python3
"""Fail if feature sheets live under Features/Sheets/ instead of Cycle/Month/More."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHEETS = ROOT / "ios/PeriMedi/Features/Sheets"
ALLOWED = {"DialogChrome.swift"}


def main() -> int:
    if not SHEETS.is_dir():
        print(f"missing {SHEETS.relative_to(ROOT)}", file=sys.stderr)
        return 2
    extra = sorted(p.name for p in SHEETS.glob("*.swift") if p.name not in ALLOWED)
    if extra:
        print(
            "Features/Sheets/ may only contain DialogChrome.swift (shared chrome).",
            file=sys.stderr,
        )
        print(
            "Move feature sheets under Features/Cycle, Features/Month, or Features/More:",
            file=sys.stderr,
        )
        for name in extra:
            print(f"  {name}", file=sys.stderr)
        return 1
    print("ok: Features/Sheets/ is shared chrome only")
    return 0


if __name__ == "__main__":
    sys.exit(main())
