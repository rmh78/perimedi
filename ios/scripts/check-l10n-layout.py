#!/usr/bin/env python3
"""Fail if Trends or Visit chrome keys still live in the L10n.swift dump."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
L10N = ROOT / "ios/PeriMedi/App/L10n.swift"
TRENDS = ROOT / "ios/PeriMedi/Features/Trends/TrendsStrings.swift"
VISIT = ROOT / "ios/PeriMedi/Features/More/VisitStrings.swift"

KEY = re.compile(r'"((?:trends|visit|more\.visit)[^"]*)"\s*:')


def main() -> int:
    missing = [p for p in (TRENDS, VISIT) if not p.is_file()]
    if missing:
        for path in missing:
            print(f"missing {path.relative_to(ROOT)}", file=sys.stderr)
        return 2
    if not L10N.is_file():
        print(f"missing {L10N.relative_to(ROOT)}", file=sys.stderr)
        return 2

    hits = sorted(set(KEY.findall(L10N.read_text(encoding="utf-8"))))
    if hits:
        print(
            "L10n.swift must not hold Trends or Visit keys. Move them next to the feature:",
            file=sys.stderr,
        )
        for key in hits:
            print(f"  {key}", file=sys.stderr)
        return 1
    print("ok: Trends and Visit keys are out of L10n.swift")
    return 0


if __name__ == "__main__":
    sys.exit(main())
