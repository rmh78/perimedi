#!/usr/bin/env python3
"""Fail when a covered symbol changes and the symptom-sync model stays put."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / ".grok/skills/check-symptom-sync/SKILL.md"
MODEL = (
    "ios/formal/symptom-sync/SymptomSync.tla",
    "ios/formal/symptom-sync/SymptomSync.cfg",
)
FIX = (
    "update ios/formal/symptom-sync/SymptomSync.tla, "
    "ios/formal/symptom-sync/SymptomSync.cfg, or the Sync commit in "
    ".grok/skills/check-symptom-sync/SKILL.md."
)
_SYNC = re.compile(r"Sync commit:\s*`([0-9a-f]{7,40})`")
_MOD = (
    r"(?:public|private|internal|fileprivate|open|static|final|override|"
    r"mutating|nonisolated|class)"
)
_DECL = re.compile(
    rf"^\s*(?:{_MOD}\s+)*(func|var|let|struct|enum|class|extension)\s+"
    rf"([A-Za-z_][A-Za-z0-9_]*)",
)
_HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", re.M)
_KINDS = {"struct", "enum", "class", "extension"}
_MEMBERS = {"func", "var", "let"}


@dataclass(frozen=True)
class Covered:
    name: str
    path: str
    owner: str | None
    member: str


@dataclass(frozen=True)
class Decl:
    kind: str
    name: str
    start: int
    end: int


@dataclass
class FileDiff:
    old: str
    new: str
    deleted: bool
    hunks: list[tuple[int, int, int, int]]


def covered_symbols(skill: str) -> list[Covered]:
    start = skill.find("## Covered code")
    if start < 0:
        return []
    rest = skill[start:]
    end = rest.find("\n## ", 1)
    body = rest if end < 0 else rest[:end]
    found: list[Covered] = []
    for line in body.splitlines():
        if not line.startswith("- "):
            continue
        ticks = re.findall(r"`([^`]+)`", line)
        path = next((tick for tick in ticks if tick.endswith(".swift")), None)
        if path is None:
            continue
        for tick in ticks:
            if tick.endswith(".swift"):
                continue
            if "." in tick:
                owner, member = tick.split(".", 1)
            else:
                owner, member = None, tick
            found.append(Covered(tick, path, owner, member))
    return found


def sync_commit(skill: str) -> str | None:
    match = _SYNC.search(skill)
    return match.group(1) if match else None


def _feed(line: str, state: str, depth: int, started: bool) -> tuple[str, int, bool, bool]:
    i = 0
    while i < len(line):
        if state == "block":
            if line.startswith("*/", i):
                state = "code"
                i += 2
            else:
                i += 1
            continue
        if state == "string":
            if line[i] == "\\":
                i += 2
                continue
            if line[i] == '"':
                state = "code"
            i += 1
            continue
        if line.startswith("//", i):
            break
        if line.startswith("/*", i):
            state = "block"
            i += 2
            continue
        if line[i] == '"':
            state = "string"
            i += 1
            continue
        if line[i] == "{":
            depth += 1
            started = True
        elif line[i] == "}" and started:
            depth -= 1
            if depth == 0:
                return state, depth, started, True
        i += 1
    return state, depth, started, False


def _end_line(lines: list[str], start: int) -> int:
    state = "code"
    depth = 0
    started = False
    for index in range(start - 1, len(lines)):
        if (
            not started
            and index > start - 1
            and _DECL.match(lines[index])
        ):
            return start
        state, depth, started, closed = _feed(lines[index], state, depth, started)
        if closed:
            return index + 1
    return start if not started else len(lines)


def declarations(text: str) -> list[Decl]:
    lines = text.splitlines()
    found: list[Decl] = []
    for number, line in enumerate(lines, 1):
        match = _DECL.match(line)
        if not match:
            continue
        found.append(
            Decl(match.group(1), match.group(2), number, _end_line(lines, number))
        )
    return found


def symbol_spans(text: str, symbol: Covered) -> list[tuple[int, int]]:
    decls = declarations(text)
    if symbol.owner:
        owners = [d for d in decls if d.kind in _KINDS and d.name == symbol.owner]
        return [
            (d.start, d.end)
            for d in decls
            if d.kind in _MEMBERS
            and d.name == symbol.member
            and any(owner.start <= d.start <= owner.end for owner in owners)
        ]
    return [(d.start, d.end) for d in decls if d.name == symbol.member]


def _span(start: int, count: int) -> range:
    if count <= 0:
        return range(0)
    return range(start, start + count)


def _hits(span: range, ranges: list[tuple[int, int]]) -> bool:
    return any(line in span for start, end in ranges for line in range(start, end + 1))


def parse_diff(diff: str) -> list[FileDiff]:
    parts = re.split(r"(?=^diff --git )", diff, flags=re.M)
    files: list[FileDiff] = []
    for part in parts:
        header = re.match(r"diff --git a/(\S+) b/(\S+)", part)
        if not header:
            continue
        files.append(
            FileDiff(
                old=header.group(1),
                new=header.group(2),
                deleted="+++ /dev/null" in part or "deleted file mode" in part,
                hunks=[
                    (
                        int(match.group(1)),
                        int(match.group(2) or 1),
                        int(match.group(3)),
                        int(match.group(4) or 1),
                    )
                    for match in _HUNK.finditer(part)
                ],
            )
        )
    return files


def model_changed(diff: str) -> bool:
    return any(
        entry.old in MODEL or entry.new in MODEL for entry in parse_diff(diff)
    )


def symbol_problem(symbol: Covered) -> str:
    return f"{symbol.name} in {symbol.path}: {FIX}"


def file_problem(path: str) -> str:
    return f"{path}: renamed or deleted covered file. {FIX}"


def hunk_problems(
    diff: str,
    covered: list[Covered],
    files: dict[str, tuple[str | None, str | None]],
    sync_before: str | None,
    sync_after: str | None,
) -> list[str]:
    if not covered or sync_before != sync_after or model_changed(diff):
        return []
    parsed = parse_diff(diff)
    paths = {symbol.path for symbol in covered}
    problems: list[str] = []
    deleted: set[str] = set()
    for entry in parsed:
        if entry.deleted and entry.old in paths and entry.old not in deleted:
            problems.append(file_problem(entry.old))
            deleted.add(entry.old)
    seen: set[str] = set()
    for symbol in covered:
        if symbol.path in deleted or symbol.name in seen:
            continue
        entry = next(
            (item for item in parsed if item.old == symbol.path or item.new == symbol.path),
            None,
        )
        if entry is None:
            continue
        base_text, head_text = files.get(symbol.path, (None, None))
        base_spans = symbol_spans(base_text, symbol) if base_text else []
        head_spans = symbol_spans(head_text, symbol) if head_text else []
        hit = False
        for old_start, old_count, new_start, new_count in entry.hunks:
            if _hits(_span(old_start, old_count), base_spans) or _hits(
                _span(new_start, new_count), head_spans
            ):
                hit = True
                break
        if hit:
            problems.append(symbol_problem(symbol))
            seen.add(symbol.name)
    return problems


def unresolved(covered: list[Covered], files: dict[str, str]) -> list[str]:
    missing: list[str] = []
    for symbol in covered:
        text = files.get(symbol.path)
        if text is None:
            missing.append(f"missing {symbol.path}")
            continue
        if not symbol_spans(text, symbol):
            missing.append(f"missing {symbol.name} in {symbol.path}")
    return missing


def git_text(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=ROOT, text=True, capture_output=True, check=False)


def show_file(rev: str, path: str) -> str | None:
    proc = git_text(["git", "show", f"{rev}:{path}"])
    if proc.returncode != 0:
        return None
    return proc.stdout


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="origin/main")
    args = parser.parse_args()
    diff_proc = git_text(
        ["git", "diff", "--no-renames", "-U0", f"{args.base}...HEAD"]
    )
    if diff_proc.returncode != 0:
        print(diff_proc.stderr.strip() or "git diff failed", file=sys.stderr)
        return 2
    if not SKILL.is_file():
        print(f"missing {SKILL.relative_to(ROOT)}", file=sys.stderr)
        return 2
    head = SKILL.read_text(encoding="utf-8")
    covered = covered_symbols(head)
    after = sync_commit(head)
    if not covered or after is None:
        print(
            "check-symptom-sync skill is missing covered symbols or the Sync commit.",
            file=sys.stderr,
        )
        return 2
    before_skill = show_file(args.base, SKILL.relative_to(ROOT).as_posix())
    paths = {symbol.path for symbol in covered}
    files = {
        path: (show_file(args.base, path), show_file("HEAD", path)) for path in paths
    }
    head_files = {path: text for path, (_, text) in files.items() if text is not None}
    missing = unresolved(covered, head_files)
    if missing:
        for item in missing:
            print(item, file=sys.stderr)
        return 2
    problems = hunk_problems(
        diff_proc.stdout,
        covered,
        files,
        sync_commit(before_skill) if before_skill else None,
        after,
    )
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        return 1
    print("ok: symptom-sync model matches covered Swift")
    return 0


if __name__ == "__main__":
    sys.exit(main())
