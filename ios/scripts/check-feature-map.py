#!/usr/bin/env python3
"""Fail if an A11yID is not named in the verify-perimedi feature map."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
A11Y = ROOT / "ios/PeriMedi/App/A11yID.swift"
FEATURES = ROOT / ".grok/skills/verify-perimedi/features"

INTERP_NESTED = re.compile(r"\\\([^()]*\([^()]*\)[^()]*\)")
INTERP_SIMPLE = re.compile(r"\\\([^()]*\)")
BRACE = re.compile(r"\{[^}]+\}")


def literals(swift: str) -> list[str]:
    return re.findall(r'"([^"]*)"', swift)


def is_identifier(lit: str) -> bool:
    return "." in lit


def normalize(s: str) -> str:
    s = INTERP_NESTED.sub("{var}", s)
    s = INTERP_SIMPLE.sub("{var}", s)
    s = BRACE.sub("{var}", s)
    return s


def backtick_needles(markdown: str) -> set[str]:
    return {normalize(body) for body in re.findall(r"`([^`]+)`", markdown)}


def main() -> int:
    if not A11Y.is_file():
        print(f"missing {A11Y.relative_to(ROOT)}", file=sys.stderr)
        return 2
    if not FEATURES.is_dir():
        print(f"missing {FEATURES.relative_to(ROOT)}", file=sys.stderr)
        return 2

    swift = A11Y.read_text(encoding="utf-8")
    corpus = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted(FEATURES.glob("*.md"))
    )
    named = backtick_needles(corpus)

    missing: list[str] = []
    checked = 0
    for lit in literals(swift):
        if not is_identifier(lit):
            continue
        checked += 1
        if normalize(lit) not in named:
            missing.append(lit)

    if missing:
        print(
            f"A11yIDs not named in {FEATURES.relative_to(ROOT)}/ "
            f"({len(missing)} of {checked}):",
            file=sys.stderr,
        )
        for item in missing:
            print(f"  {item}", file=sys.stderr)
        print(
            "Add the ID (in backticks) to the matching features/*.md "
            "in the same commit.",
            file=sys.stderr,
        )
        return 1

    print(f"ok: {checked} A11yIDs named in {FEATURES.relative_to(ROOT)}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
