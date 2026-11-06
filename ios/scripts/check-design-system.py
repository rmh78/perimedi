#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASELINE_REL = "ios/docs/design-baseline.txt"
PBXPROJ_REL = "ios/PeriMedi.xcodeproj/project.pbxproj"

KINDS = frozenset({"hex", "color-init", "font-literal"})
Key = tuple[str, str, str]

_SCAN_ROOTS = (
    "ios/PeriMedi/",
    "ios/PeriMediDoseWidget/",
    "ios/PeriMediDoseWidgetSupport/",
    "ios/Packages/PeriDesign/Sources/",
)
_TOKENS_PREFIX = "ios/Packages/PeriDesign/Sources/PeriDesign/Tokens/"
_TREE_ROOTS = (
    "ios/PeriMedi",
    "ios/PeriMediDoseWidget",
    "ios/PeriMediDoseWidgetSupport",
    "ios/Packages/PeriDesign/Sources",
)

_HEX = re.compile(r"^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")
_COLOR_INIT = re.compile(
    r"(?<![\w])(?:UIColor\(red:|UIColor\(white:|Color\(red:|Color\(white:|Color\(hue:|Color\(\.sRGB)"
)
_SYSTEM = re.compile(r"\.system\(\s*size:\s*(\d+(?:\.\d+)?|\.\d+)")
_UIFONT = re.compile(
    r"(?<![\w])UIFont\.systemFont\(\s*ofSize:\s*(\d+(?:\.\d+)?|\.\d+)"
)
_CUSTOM = re.compile(
    r"(?<![\w])(?:Font\.custom\(|\.font\(\s*\.custom\(|\.custom\(\s{2,})"
)


def violations_in(path: str, source: str) -> dict[Key, int]:
    strings, blank = _split_source(source)
    counts: dict[Key, int] = {}

    def add(kind: str, excerpt: str) -> None:
        key = (path, kind, excerpt)
        counts[key] = counts.get(key, 0) + 1

    for content in strings:
        text = content.strip()
        if _HEX.fullmatch(text):
            add("hex", text.lower())
    for match in _COLOR_INIT.finditer(blank):
        add("color-init", match.group(0))
    for match in _SYSTEM.finditer(blank):
        add("font-literal", f".system(size: {match.group(1)})")
    for match in _UIFONT.finditer(blank):
        add("font-literal", f"UIFont.systemFont(ofSize: {match.group(1)})")
    for match in _CUSTOM.finditer(blank):
        add("font-literal", ".custom(")
    return counts


def scan_tree(root: Path) -> dict[Key, int]:
    found: dict[Key, int] = {}
    for rel in _TREE_ROOTS:
        base = root / rel
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*.swift")):
            repo_path = path.relative_to(root).as_posix()
            if repo_path.startswith(_TOKENS_PREFIX):
                continue
            text = path.read_text(encoding="utf-8")
            for key, count in violations_in(repo_path, text).items():
                found[key] = found.get(key, 0) + count
    return found


def parse_baseline(text: str) -> dict[Key, int]:
    if text == "":
        return {}
    parsed = _parse_lines(text)
    if render_baseline(parsed) != text:
        raise ValueError("baseline is not canonical")
    return parsed


def render_baseline(found: dict[Key, int]) -> str:
    lines = [
        f"{path}\t{kind}\t{excerpt}\t{count}"
        for (path, kind, excerpt), count in sorted(found.items())
        if count >= 1
    ]
    if not lines:
        return ""
    return "\n".join(lines) + "\n"


def judge(
    found: dict[Key, int],
    baseline: dict[Key, int],
    mainline: dict[Key, int] | None,
) -> tuple[str, ...]:
    messages: list[str] = []
    for key in sorted(set(found) | set(baseline)):
        have = found.get(key, 0)
        want = baseline.get(key, 0)
        if have > want:
            messages.append(
                f"new violation {_fmt(key)}: use a PeriColor, PeriSpace, PeriRadius, or PeriFont token. Do not add a baseline line."
            )
        elif want > have:
            messages.append(
                f"stale baseline {_fmt(key)}: delete the line or lower the count."
            )
    if mainline is not None:
        for key in sorted(baseline):
            if key not in mainline:
                messages.append(f"baseline grew against --base: {_fmt(key)} is not on the base.")
            elif baseline[key] > mainline[key]:
                messages.append(
                    f"baseline grew against --base: {_fmt(key)} count {baseline[key]} exceeds {mainline[key]}."
                )
    return tuple(messages)


def baseline_at(base: str, git_path: str) -> str | None:
    proc = subprocess.run(
        ["git", "show", f"{base}:{git_path}"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if proc.returncode == 0:
        return proc.stdout
    err = proc.stderr or ""
    if "does not exist" in err or "exists on disk, but not in" in err:
        return None
    raise RuntimeError(err.strip() or f"git show failed ({proc.returncode})")


def linkage_errors(pbxproj: str) -> tuple[str, ...]:
    errors: list[str] = []
    if "Packages/PeriDesign" not in pbxproj:
        errors.append("project.pbxproj is missing Packages/PeriDesign")
    if pbxproj.count("productName = PeriDesign") < 2:
        errors.append("project.pbxproj needs productName = PeriDesign on the app and the widget")
    return tuple(errors)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Compare SwiftUI hex and font literals to the design baseline.")
    parser.add_argument("--base", required=True)
    args = parser.parse_args(argv)
    try:
        baseline_file = ROOT / BASELINE_REL
        if not baseline_file.is_file():
            raise ValueError(f"missing {BASELINE_REL}")
        baseline = parse_baseline(baseline_file.read_text(encoding="utf-8"))
        found = scan_tree(ROOT)
        main_text = baseline_at(args.base, BASELINE_REL)
        mainline = None if main_text is None else parse_baseline(main_text)
        messages = list(judge(found, baseline, mainline))
        pbx = (ROOT / PBXPROJ_REL).read_text(encoding="utf-8")
        messages.extend(linkage_errors(pbx))
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as err:
        print(err, file=sys.stderr)
        return 1
    if messages:
        for message in messages:
            print(message, file=sys.stderr)
        return 1
    return 0


def _fmt(key: Key) -> str:
    path, kind, excerpt = key
    return f"{path} {kind} {excerpt}"


def _baseline_path_ok(path: str) -> bool:
    if not path.endswith(".swift"):
        return False
    parts = path.split("/")
    if path.startswith("/") or "\\" in path or ".." in parts:
        return False
    if path.startswith(_TOKENS_PREFIX):
        return False
    return any(path.startswith(root) for root in _SCAN_ROOTS)


def _parse_lines(text: str) -> dict[Key, int]:
    if not text.endswith("\n"):
        raise ValueError("baseline must end with a newline")
    parsed: dict[Key, int] = {}
    for line in text.split("\n")[:-1]:
        parts = line.split("\t")
        if line == "" or len(parts) != 4:
            raise ValueError(f"bad baseline line: {line!r}")
        path, kind, excerpt, count_s = parts
        if kind not in KINDS:
            raise ValueError(f"unknown kind: {kind}")
        if not _baseline_path_ok(path):
            raise ValueError(f"baseline path is outside the scan: {path}")
        if not count_s.isdecimal() or str(int(count_s)) != count_s or int(count_s) < 1:
            raise ValueError(f"bad count: {count_s}")
        key = (path, kind, excerpt)
        if key in parsed:
            raise ValueError(f"duplicate baseline key: {path} {kind} {excerpt}")
        parsed[key] = int(count_s)
    return parsed


def _split_source(source: str) -> tuple[list[str], str]:
    n = len(source)
    i = 0
    strings: list[str] = []
    chunks: list[str] = []
    while i < n:
        if source.startswith("//", i):
            j = source.find("\n", i)
            j = n if j < 0 else j
            chunks.append(" " * (j - i))
            i = j
            continue
        if source.startswith("/*", i):
            j = _skip_block(source, i)
            chunks.append(" " * (j - i))
            i = j
            continue
        if source[i] == "#":
            hashes = _leading_hashes(source, i)
            if i + hashes < n and source[i + hashes] == '"':
                content, j = _read_raw(source, i, hashes)
                if content is not None:
                    strings.append(content)
                chunks.append(" " * (j - i))
                i = j
                continue
        if source[i] == '"':
            if source.startswith('"""', i):
                content, j = _read_multiline(source, i)
            else:
                content, j = _read_quoted(source, i)
            if content is not None:
                strings.append(content)
            chunks.append(" " * (j - i))
            i = j
            continue
        chunks.append(source[i])
        i += 1
    return strings, "".join(chunks)


def _leading_hashes(source: str, i: int) -> int:
    n = len(source)
    start = i
    while i < n and source[i] == "#":
        i += 1
    return i - start


def _skip_block(source: str, i: int) -> int:
    n = len(source)
    depth = 1
    i += 2
    while i < n and depth:
        if source.startswith("/*", i):
            depth += 1
            i += 2
        elif source.startswith("*/", i):
            depth -= 1
            i += 2
        else:
            i += 1
    return i


def _read_quoted(source: str, i: int) -> tuple[str | None, int]:
    n = len(source)
    i += 1
    chars: list[str] = []
    interpolated = False
    while i < n:
        ch = source[i]
        if ch == "\\":
            if i + 1 >= n:
                return None, n
            nxt = source[i + 1]
            if nxt == "(":
                interpolated = True
                i = _skip_interpolation(source, i + 1)
                continue
            if nxt == "u" and i + 2 < n and source[i + 2] == "{":
                end = source.find("}", i + 3)
                if end < 0:
                    return None, n
                try:
                    chars.append(chr(int(source[i + 3 : end], 16)))
                except ValueError:
                    interpolated = True
                i = end + 1
                continue
            simple = {"n": "\n", "r": "\r", "t": "\t", "\\": "\\", '"': '"', "'": "'", "0": "\0"}
            chars.append(simple.get(nxt, nxt))
            i += 2
            continue
        if ch == '"':
            return (None if interpolated else "".join(chars)), i + 1
        chars.append(ch)
        i += 1
    return None, n


def _read_multiline(source: str, i: int) -> tuple[str | None, int]:
    n = len(source)
    i += 3
    if i < n and source[i] == "\n":
        i += 1
    chars: list[str] = []
    interpolated = False
    while i < n:
        if source[i] == "\\" and i + 1 < n:
            nxt = source[i + 1]
            if nxt == "(":
                interpolated = True
                i = _skip_interpolation(source, i + 1)
                continue
            chars.append(nxt)
            i += 2
            continue
        if source.startswith('"""', i):
            return (None if interpolated else "".join(chars)), i + 3
        chars.append(source[i])
        i += 1
    return None, n


def _read_raw(source: str, i: int, hashes: int) -> tuple[str | None, int]:
    n = len(source)
    i += hashes
    if source.startswith('"""', i):
        i += 3
        if i < n and source[i] == "\n":
            i += 1
        closer = '"""' + ("#" * hashes)
    else:
        i += 1
        closer = '"' + ("#" * hashes)
    marker = "\\" + ("#" * hashes) + "("
    chars: list[str] = []
    interpolated = False
    while i < n:
        if source.startswith(marker, i):
            interpolated = True
            i = _skip_interpolation(source, i + len(marker) - 1)
            continue
        if source.startswith(closer, i):
            return (None if interpolated else "".join(chars)), i + len(closer)
        chars.append(source[i])
        i += 1
    return None, n


def _skip_interpolation(source: str, i: int) -> int:
    n = len(source)
    depth = 0
    while i < n:
        if source.startswith("//", i):
            j = source.find("\n", i)
            i = n if j < 0 else j
            continue
        if source.startswith("/*", i):
            i = _skip_block(source, i)
            continue
        if source[i] == '"':
            if source.startswith('"""', i):
                _, i = _read_multiline(source, i)
            else:
                _, i = _read_quoted(source, i)
            continue
        if source[i] == "#":
            hashes = _leading_hashes(source, i)
            if i + hashes < n and source[i + hashes] == '"':
                _, i = _read_raw(source, i, hashes)
                continue
        if source[i] == "(":
            depth += 1
            i += 1
            continue
        if source[i] == ")":
            depth -= 1
            i += 1
            if depth == 0:
                return i
            continue
        i += 1
    return i


if __name__ == "__main__":
    sys.exit(main())
