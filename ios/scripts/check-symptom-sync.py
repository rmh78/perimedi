#!/usr/bin/env python3
"""Check the custom-symptom sync model. Exit 1 when an invariant fails."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from tlc import check

ROOT = Path(__file__).resolve().parents[2]
SPEC = ROOT / "ios/formal/symptom-sync/SymptomSync.tla"
CFG = ROOT / "ios/formal/symptom-sync/SymptomSync.cfg"

SENTENCES = {
    "LateScoreKept": "A later mark for a removed copy shows on the symptom that remains.",
    "NeverCombinedHides": "A phone that never combined the pair leaves that mark hidden.",
    "WinnerGoneHides": "When the kept symptom is gone, the mark stays hidden.",
    "UniqueMarkRemains": "A mark stored under its own date and id is still on screen after a refresh.",
    "ScoreOnListedSymptom": (
        "A pair saved before the store commits does not hide a mark whose symptom is still listed."
    ),
    "EmptyKeeperSafe": "An empty record id used as the keeper does not remove a mark on another day.",
    "ImportRemembers": "A backup that combined two names stores the pair.",
    "OrphanStaysOut": (
        "A mark the file left out is not brought back by the key that wipe and import keep."
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--warn",
        action="store_true",
        help="Print a GitHub warning for each failed invariant and exit 0.",
    )
    args = parser.parse_args()
    return check(
        SPEC,
        CFG,
        SENTENCES,
        warn=args.warn,
        warning_title="Symptom sync",
        model_name="symptom-sync",
    )


if __name__ == "__main__":
    sys.exit(main())
