#!/usr/bin/env python3
"""Fail if Trends or Visit keys live in L10n.swift, en/de tables disagree, a user-facing DateFormatter sits outside DateCopy.swift, or German copy contains Beschwerde."""
from __future__ import annotations

import json
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


FORMATTER = re.compile(r"(?<![A-Za-z0-9])DateFormatter\(")
TEMPLATE = "setLocalizedDateFormatFromTemplate"
NOUN = re.compile(r"beschwerde", re.IGNORECASE)
PRESENTATION_ROOTS = (
    ROOT / "ios/PeriMedi",
    ROOT / "ios/PeriMediDoseWidget",
    ROOT / "ios/PeriMediDoseWidgetSupport",
    ROOT / "ios/Sources/PeriMediDomain",
)


def presentation_formatter_leaks() -> list[str]:
    leaks: list[str] = []
    for root in PRESENTATION_ROOTS:
        if not root.is_dir():
            continue
        for path in sorted(root.rglob("*.swift")):
            text = path.read_text(encoding="utf-8")
            if path.name == "DateCopy.swift":
                continue
            if path.name == "DateKeys.swift":
                if TEMPLATE in text:
                    leaks.append(path.relative_to(ROOT).as_posix())
                continue
            if FORMATTER.search(text) or TEMPLATE in text:
                leaks.append(path.relative_to(ROOT).as_posix())
    return leaks


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


def contains_noun(value: str) -> bool:
    return NOUN.search(value) is not None


def german_map_values(de: dict[str, str]) -> list[str]:
    return list(de.values())


def xcstrings_german_units(document: object) -> list[str]:
    found: list[str] = []

    def walk(node: object, in_de: bool, parent: str | None) -> None:
        if isinstance(node, dict):
            if in_de and parent == "stringUnit":
                value = node.get("value")
                if isinstance(value, str):
                    found.append(value)
            for key, child in node.items():
                if not isinstance(key, str):
                    continue
                walk(child, in_de or (key == "de" and parent == "localizations"), key)
        elif isinstance(node, list):
            for child in node:
                walk(child, in_de, parent)

    walk(document, False, None)
    return found


def swift_string_literals(source: str) -> list[str]:
    literals: list[str] = []
    i = 0
    n = len(source)
    while i < n:
        if source.startswith("//", i):
            nl = source.find("\n", i)
            i = n if nl < 0 else nl + 1
            continue
        if source.startswith("/*", i):
            i = _skip_block(source, i)
            continue
        if source[i] == '"':
            literal, nxt = _read_string(source, i)
            if literal is not None:
                literals.append(literal)
            i = nxt if nxt > i else i + 1
            continue
        i += 1
    return literals


def _skip_block(source: str, i: int) -> int:
    depth = 0
    n = len(source)
    while i < n - 1:
        if source.startswith("/*", i):
            depth += 1
            i += 2
            continue
        if source.startswith("*/", i):
            depth -= 1
            i += 2
            if depth == 0:
                return i
            continue
        i += 1
    return n


def _read_string(source: str, i: int) -> tuple[str | None, int]:
    n = len(source)
    if source.startswith('"""', i):
        j = i + 3
        buf: list[str] = []
        while j < n:
            if source.startswith('"""', j):
                return "".join(buf), j + 3
            if source[j] == "\\" and j + 1 < n:
                if source[j + 1] == "(":
                    j = _skip_interpolation(source, j + 1)
                    continue
                buf.append(source[j + 1])
                j += 2
                continue
            buf.append(source[j])
            j += 1
        return None, n
    j = i + 1
    buf = []
    while j < n:
        ch = source[j]
        if ch == "\\":
            if j + 1 < n and source[j + 1] == "(":
                j = _skip_interpolation(source, j + 1)
                continue
            if j + 1 < n:
                buf.append(source[j + 1])
                j += 2
                continue
        if ch == '"':
            return "".join(buf), j + 1
        if ch == "\n":
            return None, j
        buf.append(ch)
        j += 1
    return None, n


def _skip_interpolation(source: str, i: int) -> int:
    depth = 0
    n = len(source)
    while i < n:
        if source.startswith("//", i):
            nl = source.find("\n", i)
            i = n if nl < 0 else nl + 1
            continue
        if source.startswith("/*", i):
            i = _skip_block(source, i)
            continue
        ch = source[i]
        if ch == '"':
            _, i = _read_string(source, i)
            continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            i += 1
            if depth == 0:
                return i
            continue
        i += 1
    return n


def self_check() -> bool:
    failed = False

    def expect(ok: bool, message: str) -> None:
        nonlocal failed
        if not ok:
            print(f"self_check: {message}", file=sys.stderr)
            failed = True

    expect(contains_noun("Beschwerden"), "German value Beschwerden should fail")
    expect(not contains_noun("Symptom"), "German value Symptom should pass")

    english = "Track your Beschwerden today"
    scanned = german_map_values({"legend.symptom": "Symptom"})
    units = xcstrings_german_units(
        {
            "strings": {
                "legend.symptom": {
                    "localizations": {
                        "en": {"stringUnit": {"value": english}},
                        "de": {"stringUnit": {"value": "Symptom"}},
                    }
                }
            }
        }
    )
    passed_in = scanned + units
    expect(english not in passed_in, "an English sentence is not passed in")
    expect(not any(contains_noun(value) for value in passed_in), "Symptom should pass")

    source = '\n'.join(
        [
            "// Beschwerde in a comment",
            "/* Beschwerde block */",
            "let beschwerdeCount = 1",
            'let label = "Symptom"',
        ]
    )
    literals = swift_string_literals(source)
    expect(literals == ["Symptom"], f"comment is not a literal ({literals})")
    expect("beschwerdeCount" not in literals, "identifier beschwerdeCount is not a literal")
    expect(not any(contains_noun(value) for value in literals), "comment text should not be scanned")
    return not failed


def noun_hits(maps: dict[Path, dict[str, dict[str, str]]]) -> list[str]:
    hits: list[str] = []
    for path in TABLES:
        for key, value in maps[path]["de"].items():
            if contains_noun(value):
                hits.append(f"{path.relative_to(ROOT)} de {key}: {value}")
    ios = ROOT / "ios"
    if ios.is_dir():
        for path in sorted(ios.rglob("*.xcstrings")):
            try:
                document = json.loads(path.read_text(encoding="utf-8"))
            except json.JSONDecodeError as error:
                hits.append(f"{path.relative_to(ROOT)}: {error}")
                continue
            for value in xcstrings_german_units(document):
                if contains_noun(value):
                    hits.append(f"{path.relative_to(ROOT)}: {value}")
    tables = {path.resolve() for path in TABLES}
    for root in PRESENTATION_ROOTS:
        if not root.is_dir():
            continue
        for path in sorted(root.rglob("*.swift")):
            if path.resolve() in tables:
                continue
            for value in swift_string_literals(path.read_text(encoding="utf-8")):
                if contains_noun(value):
                    hits.append(f"{path.relative_to(ROOT)}: {value}")
    return hits


def main() -> int:
    if not self_check():
        return 1

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
    date_copy = ROOT / "ios/Sources/PeriMediDomain/DateCopy.swift"
    if not date_copy.is_file():
        failed = True
        print("ios/Sources/PeriMediDomain/DateCopy.swift: missing", file=sys.stderr)
        dates = ""
    else:
        dates = date_copy.read_text(encoding="utf-8")
    if "DateCopy.periodHistory" not in period or "language ==" in period:
        failed = True
        print(
            f"{PERIOD.relative_to(ROOT)}: history must call DateCopy.periodHistory with no language branch",
            file=sys.stderr,
        )
    if "\\u{2013}" not in dates or "\\u{2192}" not in dates:
        failed = True
        print(
            "ios/Sources/PeriMediDomain/DateCopy.swift: closed join and open period arrow are missing",
            file=sys.stderr,
        )
    for path in presentation_formatter_leaks():
        failed = True
        print(f"{path}: user-facing DateFormatter outside DateCopy.swift", file=sys.stderr)

    for hit in noun_hits(maps):
        failed = True
        print(hit, file=sys.stderr)

    if failed:
        return 1
    print("ok: Trends and Visit keys are out of L10n.swift; en/de tables match")
    return 0


if __name__ == "__main__":
    sys.exit(main())
