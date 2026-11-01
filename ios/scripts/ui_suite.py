#!/usr/bin/env python3
"""xcodebuild filters for the PeriMedi UI suites."""

from __future__ import annotations

import sys

SUITES = {
    "smoke": [
        "-only-testing:PeriMediUITests/RequiredJourneyTests/testEnglishSmoke",
        "-only-testing:PeriMediTests",
    ],
    "full": [],
}


def args(suite: str) -> list[str]:
    try:
        return list(SUITES[suite])
    except KeyError:
        raise SystemExit(f"unknown suite {suite}") from None


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        raise SystemExit("usage: ui_suite.py smoke|full")
    for word in args(argv[1]):
        print(word)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
