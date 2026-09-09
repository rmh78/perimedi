#!/usr/bin/env python3
"""Fail if an expected screen-catalog PNG is missing. No pixel compare."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCREENS = ROOT / "ios/docs/screens"
EXPECTED = SCREENS / "expected.txt"


def main() -> int:
    if not EXPECTED.is_file():
        print(f"missing {EXPECTED.relative_to(ROOT)}", file=sys.stderr)
        return 2
    names = [
        line.strip()
        for line in EXPECTED.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    if not names:
        print(f"empty {EXPECTED.relative_to(ROOT)}", file=sys.stderr)
        return 2
    missing = [name for name in names if not (SCREENS / name).is_file()]
    if missing:
        print(
            f"screen catalog missing {len(missing)} of {len(names)} "
            f"in {SCREENS.relative_to(ROOT)}/:",
            file=sys.stderr,
        )
        for name in missing:
            print(f"  {name}", file=sys.stderr)
        print(
            "UI tests write these PNGs. Commit ios/docs/screens/. "
            "Do not paste screenshot galleries on the PR.",
            file=sys.stderr,
        )
        return 1
    print(f"ok: {len(names)} screen-catalog PNGs in {SCREENS.relative_to(ROOT)}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
