#!/usr/bin/env python3
"""Fail if Trends or Visit keys live in L10n.swift, or en/de tables disagree."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
L10N = ROOT / "ios/PeriMedi/App/L10n.swift"
TRENDS = ROOT / "ios/PeriMedi/Features/Trends/TrendsStrings.swift"
VISIT = ROOT / "ios/PeriMedi/Features/More/VisitStrings.swift"
WIDGET = ROOT / "ios/PeriMedi/App/DoseWidgetStrings.swift"
DIALOG = ROOT / "ios/PeriMedi/Features/Sheets/DialogChrome.swift"
PERIOD = ROOT / "ios/PeriMedi/Features/Cycle/PeriodSheet.swift"

KEY = re.compile(r'"((?:trends|visit|more\.visit)[^"]*)"\s*:')
PAIR = re.compile(r'"((?:\\.|[^"\\])*)"\s*:\s*"((?:\\.|[^"\\])*)"', re.S)

TABLES = (L10N, TRENDS, VISIT, WIDGET)

PINS = (
    (L10N, "nav.cycle", "Zyklus", False),
    (L10N, "nav.month", "Monat", False),
    (L10N, "nav.trends", "Verlauf", False),
    (L10N, "nav.more", "Mehr", False),
    (L10N, "common.cancel", "Abbrechen", False),
    (L10N, "period.deleteNamed", "{{name}} löschen?", False),
    (L10N, "symptom.deleteScores", "löschen", True),
    (WIDGET, "widget.take.action", "Nehmen", False),
    (WIDGET, "widget.still.title", "Heute noch einnehmen", False),
    (WIDGET, "widget.done.title", "Heute alles genommen", False),
    (WIDGET, "widget.empty.title", "Heute nichts zu nehmen", False),
)


def unescape(value: str) -> str:
    return value.replace(r"\"", '"').replace(r"\\", "\\")


def dictionary_body(source: str, name: str) -> str | None:
    static = re.search(rf"static let {name}\b[^=]*=\s*\[", source)
    if static:
        return balanced(source, static.end() - 1)
    case = re.search(rf"\.{name}\s*:\s*\[", source)
    if case:
        return balanced(source, case.end() - 1)
    return None


def balanced(source: str, open_at: int) -> str:
    depth = 0
    i = open_at
    in_string = False
    escape = False
    while i < len(source):
        ch = source[i]
        if in_string:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
        else:
            if ch == '"':
                in_string = True
            elif ch == "[":
                depth += 1
            elif ch == "]":
                depth -= 1
                if depth == 0:
                    return source[open_at + 1 : i]
        i += 1
    raise ValueError(f"unbalanced dictionary at {open_at}")


def string_map(source: str, name: str) -> dict[str, str]:
    body = dictionary_body(source, name)
    if body is None:
        raise ValueError(f"no {name} dictionary")
    out: dict[str, str] = {}
    for key, value in PAIR.findall(body):
        out[unescape(key)] = unescape(value)
    return out


def main() -> int:
    missing = [p for p in (*TABLES, DIALOG, PERIOD) if not p.is_file()]
    if missing:
        for path in missing:
            print(f"missing {path.relative_to(ROOT)}", file=sys.stderr)
        return 2

    l10n_text = L10N.read_text(encoding="utf-8")
    hits = sorted(set(KEY.findall(l10n_text)))
    if hits:
        print(
            "L10n.swift must not hold Trends or Visit keys. Move them next to the feature:",
            file=sys.stderr,
        )
        for key in hits:
            print(f"  {key}", file=sys.stderr)
        return 1

    maps: dict[Path, dict[str, dict[str, str]]] = {}
    failed = False
    for path in TABLES:
        text = path.read_text(encoding="utf-8")
        try:
            en = string_map(text, "en")
            de = string_map(text, "de")
        except ValueError as error:
            print(f"{path.relative_to(ROOT)}: {error}", file=sys.stderr)
            return 1
        maps[path] = {"en": en, "de": de}
        en_keys = set(en)
        de_keys = set(de)
        only_en = sorted(en_keys - de_keys)
        only_de = sorted(de_keys - en_keys)
        empty_de = sorted(key for key in en_keys & de_keys if not de[key].strip())
        empty_en = sorted(key for key in en_keys & de_keys if not en[key].strip())
        if only_en or only_de or empty_de or empty_en:
            failed = True
            print(f"{path.relative_to(ROOT)}: en/de tables disagree", file=sys.stderr)
            for key in only_en:
                print(f"  en only: {key}", file=sys.stderr)
            for key in only_de:
                print(f"  de only: {key}", file=sys.stderr)
            for key in empty_en:
                print(f"  empty en: {key}", file=sys.stderr)
            for key in empty_de:
                print(f"  empty de: {key}", file=sys.stderr)

    for path, key, expected, contains in PINS:
        actual = maps[path]["de"].get(key)
        ok = actual is not None and (expected in actual if contains else actual == expected)
        if not ok:
            failed = True
            print(
                f"{path.relative_to(ROOT)} de {key!r} is {actual!r}, wanted {expected!r}",
                file=sys.stderr,
            )

    dialog = DIALOG.read_text(encoding="utf-8")
    if "TT.MM.JJJJ" not in dialog:
        failed = True
        print(f"{DIALOG.relative_to(ROOT)}: missing TT.MM.JJJJ", file=sys.stderr)

    period = PERIOD.read_text(encoding="utf-8")
    if "language == .de" not in period or ".–" not in period:
        failed = True
        print(
            f"{PERIOD.relative_to(ROOT)}: .de same-month branch must keep the .– range",
            file=sys.stderr,
        )

    if failed:
        return 1
    print("ok: Trends and Visit keys are out of L10n.swift; en/de tables match")
    return 0


if __name__ == "__main__":
    sys.exit(main())
