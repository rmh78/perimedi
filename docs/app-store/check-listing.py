#!/usr/bin/env python3

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent

BANNED = (
    "titrat",
    "second device",
    "another device",
    "anderen Gerät",
    "zweiten Gerät",
    "HRT is working",
    "HRT wirkt",
    "treats menopause",
    "behandelt die Wechseljahre",
)


def line_value(text: str, prefix: str) -> str | None:
    for line in text.splitlines():
        if line.startswith(prefix):
            return line[len(prefix) :].strip()
    return None


def section(text: str, heading: str) -> str | None:
    lines = text.splitlines()
    start = None
    for index, line in enumerate(lines):
        if line.strip() == heading:
            start = index + 1
            break
    if start is None:
        return None
    body: list[str] = []
    for line in lines[start:]:
        if line.startswith("#"):
            break
        body.append(line)
    while body and not body[0].strip():
        body.pop(0)
    while body and not body[-1].strip():
        body.pop()
    return "\n".join(body).strip()


def main() -> int:
    errors: list[str] = []
    files = {
        "en": (ROOT / "listing-en.md").read_text(encoding="utf-8"),
        "de": (ROOT / "listing-de.md").read_text(encoding="utf-8"),
    }
    limits = (
        ("en", "**Subtitle (30):**", 30, False),
        ("de", "**Untertitel (30):**", 30, False),
    )
    for locale, prefix, limit, _ in limits:
        value = line_value(files[locale], prefix)
        if value is None:
            errors.append(f"missing {prefix}")
        elif len(value) > limit:
            errors.append(f"{prefix} is {len(value)} characters")

    blocks = (
        ("en", "## Promotional text (170)", 170),
        ("de", "## Werbetext (170)", 170),
        ("en", "## Keywords (100)", 100),
        ("de", "## Keywords (100)", 100),
    )
    for locale, heading, limit in blocks:
        value = section(files[locale], heading)
        if value is None:
            errors.append(f"missing {heading} in {locale}")
            continue
        if len(value) > limit:
            errors.append(f"{heading} in {locale} is {len(value)} characters")
        if "Keywords" in heading and (" " in value or "\n" in value):
            errors.append(f"{heading} in {locale} contains whitespace")

    combined = "\n".join(files.values()).lower()
    if "beschwerde" in combined:
        errors.append("beschwerde is present")
    for phrase in BANNED:
        if phrase.lower() in combined:
            errors.append(f"banned phrase: {phrase}")

    for token in ("Trends", "PDF", "widget", "your own"):
        if token not in files["en"]:
            errors.append(f"english listing missing {token}")
    for token in ("Verlauf", "PDF", "Widget", "eigene"):
        if token not in files["de"]:
            errors.append(f"german listing missing {token}")

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
