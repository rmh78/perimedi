#!/usr/bin/env python3

from __future__ import annotations

import sys

from harness_gates import FEATURES, run_gate


def main() -> int:
    return run_gate(FEATURES)


if __name__ == "__main__":
    raise SystemExit(main())
