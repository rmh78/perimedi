#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

_SKIP_SWIFT = (
    "ios/PeriMediUITests/",
    "ios/PeriMediTests/",
    "ios/Tests/",
)
_PRODUCT_SWIFT = (
    "ios/PeriMedi/",
    "ios/Sources/",
)
_L10N = "ios/PeriMedi/App/L10n.swift"
_GERMAN_MONTHS = (
    "Januar",
    "Februar",
    "März",
    "April",
    "Mai",
    "Juni",
    "Juli",
    "August",
    "September",
    "Oktober",
    "November",
    "Dezember",
)
_ENGLISH_MONTHS = (
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
)
_LANGUAGE = re.compile(r'languageCode == \.german \? "')
_DECIMAL = re.compile(r'replacingOccurrences\(of: "\.", with: ","\)')
_GLUE = (
    re.compile(r"(?<!\d)\d+ minutes"),
    re.compile(r"(?<!\d)\d+ Minuten"),
    re.compile(r"(?<!\d)\d+\. (?:%s)(?!\w)" % "|".join(_GERMAN_MONTHS)),
    re.compile(
        r"(?<![A-Za-z])(?:%s) \d{1,2}(?!\d)" % "|".join(_ENGLISH_MONTHS)
    ),
)


class GitError(Exception):
    pass


def _product_swift(path: str) -> bool:
    if not path.endswith(".swift") or path.startswith(_SKIP_SWIFT):
        return False
    return path.startswith(_PRODUCT_SWIFT)


def _glue_path(path: str) -> bool:
    return path == _L10N or Path(path).name == "Localizable.xcstrings"


def _added_lines(diff_text: str) -> list[tuple[str, str]]:
    path = ""
    in_hunk = False
    found: list[tuple[str, str]] = []
    for line in diff_text.splitlines():
        if line.startswith("diff --git "):
            in_hunk = False
            path = ""
            if " b/" in line:
                path = line.rsplit(" b/", 1)[1]
                if len(path) >= 2 and path[0] == '"' and path[-1] == '"':
                    path = path[1:-1]
            continue
        if line.startswith("+++ "):
            spec = line[4:].strip()
            if len(spec) >= 2 and spec[0] == '"' and spec[-1] == '"':
                spec = spec[1:-1]
            if spec == "/dev/null":
                path = ""
            elif spec.startswith("b/"):
                path = spec[2:]
            else:
                path = spec
            continue
        if line.startswith("@@"):
            in_hunk = True
            continue
        if in_hunk and line.startswith("+") and not line.startswith("++"):
            found.append((path, line[1:]))
    return found


def _line_problems(path: str, line: str) -> list[str]:
    problems: list[str] = []
    if _product_swift(path):
        if _LANGUAGE.search(line):
            problems.append(
                f"{path}: use app.t for both languages. Found a language-code string."
            )
        if "YYYY-MM-DD" in line:
            problems.append(
                f"{path}: use DateCopy for an empty date. Found 'YYYY-MM-DD'."
            )
        if _DECIMAL.search(line):
            problems.append(
                f"{path}: use DoseUnitCopy with the app language. Found a decimal-point swap."
            )
    if _glue_path(path):
        for pattern in _GLUE:
            for match in pattern.finditer(line):
                problems.append(
                    f"{path}: use U+00A0 between the number and the word. Found {match.group(0)!r}."
                )
    return problems


def repeat_problems(diff_text: str) -> list[str]:
    problems: list[str] = []
    for path, line in _added_lines(diff_text):
        problems.extend(_line_problems(path, line))
    return problems


def load_base(ref: str) -> str:
    parsed = subprocess.run(
        ["git", "-C", str(ROOT), "rev-parse", "--verify", "--quiet", ref],
        capture_output=True,
    )
    if parsed.returncode != 0 or not parsed.stdout.strip():
        raise GitError(f"missing ref: {ref}")
    base = subprocess.run(
        ["git", "-C", str(ROOT), "merge-base", ref, "HEAD"],
        capture_output=True,
    )
    if base.returncode != 0 or not base.stdout.strip():
        message = base.stderr.decode("utf-8", errors="replace").strip()
        raise GitError(message or f"missing ref: {ref}")
    merge_base = base.stdout.decode().strip()
    diff = subprocess.run(
        ["git", "-C", str(ROOT), "diff", "--find-renames", merge_base, "HEAD"],
        capture_output=True,
    )
    if diff.returncode != 0:
        message = diff.stderr.decode("utf-8", errors="replace").strip()
        raise GitError(message or "git diff failed")
    return diff.stdout.decode("utf-8", errors="replace")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="check-review-repeats.py")
    parser.add_argument("--diff-file")
    parser.add_argument("--base")
    args = parser.parse_args(argv)
    if args.diff_file is not None and args.base is not None:
        parser.error("pass only one of --diff-file and --base")
    try:
        if args.diff_file is not None:
            path = Path(args.diff_file)
            if not path.is_file():
                print(f"missing diff file: {path}", file=sys.stderr)
                return 1
            text = path.read_text(encoding="utf-8")
        else:
            text = load_base(args.base if args.base is not None else "origin/main")
    except (GitError, OSError) as exc:
        print(exc, file=sys.stderr)
        return 1
    problems = repeat_problems(text)
    if problems:
        print("\n".join(problems))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
