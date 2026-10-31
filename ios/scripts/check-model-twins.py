#!/usr/bin/env python3

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LEFT = ROOT / "ios/scripts/check-symptom-model.py"
RIGHT = ROOT / "ios/scripts/check-dose-reminder-model.py"

# Longer tokens first so check-symptom-sync is not split into a leftover suffix.
TOKENS = (
    "check-symptom-sync",
    "check-dose-reminder",
    "symptom-sync",
    "dose-reminder",
    "SymptomSync",
    "DoseReminder",
)


def scrub(text: str) -> str:
    for token in TOKENS:
        text = text.replace(token, "FEATURE")
    return text


def main(argv: list[str]) -> int:
    left = Path(argv[1]) if len(argv) > 1 else LEFT
    right = Path(argv[2]) if len(argv) > 2 else RIGHT
    if scrub(left.read_text(encoding="utf-8")) != scrub(right.read_text(encoding="utf-8")):
        print("the covered-symbol checkers differ by more than the feature name", file=sys.stderr)
        return 1
    print("ok: covered-symbol checkers match")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
