#!/usr/bin/env python3

from __future__ import annotations

import argparse
import sys

from harness_gates import agent_checks, run_gate


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="check-agent.py")
    parser.add_argument("--base", default="origin/main")
    args = parser.parse_args(argv)
    return run_gate(agent_checks(args.base))


if __name__ == "__main__":
    raise SystemExit(main())
