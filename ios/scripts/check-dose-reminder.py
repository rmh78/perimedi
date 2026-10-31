#!/usr/bin/env python3
"""Check the dose reminder model. Exit 1 when an invariant fails."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from tlc import check

ROOT = Path(__file__).resolve().parents[2]
SPEC = ROOT / "ios/formal/dose-reminder/DoseReminder.tla"
CFG = ROOT / "ios/formal/dose-reminder/DoseReminder.cfg"

SENTENCES = {
    "TakenNotPending": "A taken dose leaves no reminder that can still fire.",
    "WritersAgree": "At most one row for the slot, and those rows share one status.",
    "WidgetHidesTaken": "A taken dose is not on the widget.",
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
        warning_title="Dose reminder",
        model_name="dose-reminder",
    )


if __name__ == "__main__":
    sys.exit(main())
