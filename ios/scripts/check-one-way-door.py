#!/usr/bin/env python3
"""Warn when a diff crosses a one-way door. Report mode exits 0."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

_MODEL = re.compile(r"(?<![A-Za-z0-9_])@Model(?![A-Za-z0-9_])")
_MEMBER = re.compile(
    r"^\s*"
    r"(?:(?:public|private|internal|fileprivate|open|final|override|static|class|"
    r"unowned|weak|lazy|nonisolated|package)(?:\([^)\n]*\))?\s+)*"
    r"(?:@[A-Za-z_][A-Za-z0-9_]*(?:\([^)\n]*\))?\s+)*"
    r"(?P<kind>let|var)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\b"
)
_TYPE = re.compile(
    r"\b(?:struct|enum|class|actor|extension)\s+(?P<name>ExportPayload|BackupCodec)\b"
)
_WIDGET_TYPE = re.compile(
    r"\b(?:struct|enum|class|actor|extension)\s+"
    r"(?P<name>DoseWidgetSnapshot|DoseWidgetChrome)\b"
)
_OPEN_TYPE = re.compile(r"\b(?:struct|enum|class|actor|extension)\b")
_VERSION = re.compile(r"(?<![A-Za-z0-9_])version(?![A-Za-z0-9_])")
_IDENT = r"[A-Za-z0-9_]"
_SCHEMA = re.compile("(?<!" + _IDENT + ")schemaVersion(?!" + _IDENT + ")")
_CASE_ITEM = re.compile(
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)(?:\s*=\s*\"(?P<raw>[^\"]*)\")?"
)
_JSON_KEY = re.compile(r'^\s*"(?P<name>[A-Za-z0-9_]+)"\s*:')
_SIGNING = (
    "com.apple.developer",
    "com.apple.security.application-groups",
    "NSPrivacy",
    "CODE_SIGN",
    "DEVELOPMENT_TEAM",
    "PROVISIONING_PROFILE",
)


@dataclass(frozen=True)
class FileDiff:
    path: str
    added: tuple[str, ...]
    removed: tuple[str, ...]
    old_text: str
    new_text: str


@dataclass(frozen=True)
class Diff:
    files: tuple[FileDiff, ...]


@dataclass(frozen=True)
class _RawFile:
    old_path: str | None
    new_path: str | None
    added: tuple[str, ...]
    removed: tuple[str, ...]
    old_hunk: str
    new_hunk: str


class MissingRef(Exception):
    pass


def _join(items: list[str]) -> str | None:
    if not items:
        return None
    if len(items) <= 5:
        return "; ".join(items)
    return "; ".join(items[:5]) + f"; +{len(items) - 5} more"


def _blob(file: FileDiff) -> str:
    return "\n".join(
        (file.path, file.old_text, file.new_text, "\n".join(file.added), "\n".join(file.removed))
    )


def _stored_var(line: str) -> bool:
    if "{" in line:
        return False
    match = _MEMBER.match(line)
    return match is not None and match.group("kind") == "var"


def swiftdata(diff: Diff) -> str | None:
    hits: list[str] = []
    for file in diff.files:
        if not file.path.endswith(".swift"):
            continue
        has_model = _MODEL.search(file.old_text) is not None or _MODEL.search(file.new_text) is not None
        for kind, lines in (("added", file.added), ("removed", file.removed)):
            for line in lines:
                if _MODEL.search(line):
                    hits.append(f"{kind} @Model in {file.path}")
                elif has_model and _stored_var(line):
                    hits.append(f"{kind} stored var in {file.path}")
    return _join(hits)


def _brace_body(text: str, start: int) -> str | None:
    brace = text.find("{", start)
    if brace < 0:
        return None
    depth = 0
    for index in range(brace, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[brace + 1 : index]
    return None


def _bodies(text: str, pattern: re.Pattern[str]) -> tuple[str, ...] | None:
    bodies: list[str] = []
    for match in pattern.finditer(text):
        body = _brace_body(text, match.end())
        if body is None:
            return None
        bodies.append(body)
    return tuple(bodies)


def _version_ints(body: str) -> list[int]:
    found: list[int] = []
    for line in body.splitlines():
        if _VERSION.search(line):
            found.extend(int(item) for item in re.findall(r"\d+", line))
    return found


def _case_wires(body: str) -> set[str] | None:
    names: set[str] = set()
    for line in body.splitlines():
        code = line.split("//", 1)[0]
        matched = re.search(r"\bcase\b(.*)$", code)
        if matched is None:
            continue
        for part in matched.group(1).split(","):
            part = part.strip()
            if not part:
                continue
            item = _CASE_ITEM.fullmatch(part)
            if item is None:
                return None
            names.add(item.group("raw") if item.group("raw") is not None else item.group("name"))
    if not names:
        return None
    return names


def _coding_wires(body: str) -> tuple[bool, set[str]] | None:
    found = list(re.finditer(r"\benum\s+CodingKeys\b", body))
    if not found:
        return False, set()
    names: set[str] = set()
    for match in found:
        inner = _brace_body(body, match.end())
        if inner is None:
            return None
        wires = _case_wires(inner)
        if wires is None:
            return None
        names |= wires
    return True, names


def _depth0_wires(body: str) -> set[str]:
    names: set[str] = set()
    depth = 0
    for line in body.splitlines():
        if depth == 0:
            match = _MEMBER.match(line.split("//", 1)[0])
            if match is not None and "{" not in line:
                names.add(match.group("name"))
        depth += line.count("{") - line.count("}")
        if depth < 0:
            depth = 0
    return names


def _payload_facts(text: str) -> tuple[frozenset[str], tuple[int, ...]] | None:
    bodies = _bodies(text, _TYPE)
    if bodies is None:
        return None
    wires: set[str] = set()
    versions: list[int] = []
    for body in bodies:
        versions.extend(_version_ints(body))
        coded = _coding_wires(body)
        if coded is None:
            return None
        present, coded_names = coded
        if present:
            wires |= coded_names
        else:
            wires |= _depth0_wires(body)
    return frozenset(wires), tuple(sorted(versions))


def _decl_lines(text: str, name: str) -> list[str]:
    found: list[str] = []
    for line in text.splitlines():
        match = _MEMBER.match(line.split("//", 1)[0])
        if match is not None and match.group("name") == name:
            found.append(line)
    return found


def _new_wire(text: str, name: str) -> str:
    lines = _decl_lines(text, name)
    if len(lines) != 1 or "{" in lines[0]:
        return f"unknown wire key: {name}"
    line = lines[0]
    if "?" in line or "Optional<" in line:
        return ""
    return f"required wire key: {name}"


def backup_v1(diff: Diff) -> str | None:
    hits: list[str] = []
    for file in diff.files:
        blob = _blob(file)
        if "ExportPayload" not in blob and "BackupCodec" not in blob:
            continue
        old = _payload_facts(file.old_text)
        new = _payload_facts(file.new_text)
        if old is None or new is None:
            hits.append(f"unknown: could not isolate ExportPayload/BackupCodec in {file.path}")
            continue
        old_wires, old_versions = old
        new_wires, new_versions = new
        if old_versions != new_versions:
            hits.append(f"version literal changed in {file.path}")
        for name in sorted(old_wires - new_wires):
            hits.append(f"wire key removed: {name}")
        for name in sorted(new_wires - old_wires):
            detail = _new_wire(file.new_text, name)
            if detail:
                hits.append(detail)
    return _join(hits)


def _member_names(body: str) -> set[str]:
    frames = ["type"]
    names: set[str] = set()
    for line in body.splitlines():
        code = line.split("//", 1)[0]
        if frames[-1] == "type":
            match = _MEMBER.match(code)
            if match is not None:
                names.add(match.group("name"))
        cursor = 0
        for index, char in enumerate(code):
            if char == "{":
                prefix = code[cursor:index]
                frames.append("type" if _OPEN_TYPE.search(prefix) else "other")
                cursor = index + 1
            elif char == "}" and len(frames) > 1:
                frames.pop()
                cursor = index + 1
    return names


def _schema_ints(text: str) -> list[int]:
    found: list[int] = []
    for line in text.splitlines():
        if _SCHEMA.search(line):
            found.extend(int(item) for item in re.findall(r"\d+", line))
    return found


def _json_keys(text: str) -> set[str]:
    return {match.group("name") for match in _JSON_KEY.finditer(text)}


def _widget_facts(text: str, path: str) -> tuple[frozenset[str], tuple[int, ...]] | None:
    bodies = _bodies(text, _WIDGET_TYPE)
    if bodies is None:
        return None
    names: set[str] = set()
    schemas: list[int] = []
    for body in bodies:
        names |= _member_names(body)
        schemas.extend(_schema_ints(body))
    if "next-dose.json" in text or "next-dose.json" in path:
        names |= _json_keys(text)
        if not bodies:
            schemas.extend(_schema_ints(text))
    return frozenset(names), tuple(sorted(schemas))


def widget_snapshot(diff: Diff) -> str | None:
    hits: list[str] = []
    markers = ("DoseWidgetSnapshot", "DoseWidgetChrome", "next-dose.json")
    for file in diff.files:
        blob = _blob(file)
        if not any(marker in blob for marker in markers):
            continue
        old = _widget_facts(file.old_text, file.path)
        new = _widget_facts(file.new_text, file.path)
        if old is None or new is None:
            hits.append(f"unknown widget body in {file.path}")
            continue
        old_names, old_schema = old
        new_names, new_schema = new
        if old_schema != new_schema:
            hits.append(f"schemaVersion changed in {file.path}")
        for name in sorted(old_names - new_names):
            hits.append(f"let or var removed: {name} in {file.path}")
        for name in sorted(new_names - old_names):
            hits.append(f"let or var added: {name} in {file.path}")
    return _join(hits)


def entitlements_privacy_manifest_release_and_signing(diff: Diff) -> str | None:
    hits: list[str] = []
    for file in diff.files:
        for kind, lines in (("added", file.added), ("removed", file.removed)):
            for line in lines:
                for needle in _SIGNING:
                    if needle in line:
                        hits.append(f"{kind} {needle} in {file.path}")
                        break
    return _join(hits)


DOORS = (
    swiftdata,
    backup_v1,
    widget_snapshot,
    entitlements_privacy_manifest_release_and_signing,
)


def report(diff: Diff) -> str:
    hits: list[str] = []
    for door in DOORS:
        detail = door(diff)
        if detail is not None:
            hits.append(f"{door.__name__}: {detail}")
    if not hits:
        return "one-way door: no\nreason: no detector matched\n"
    return "one-way door: yes\nreason: " + "; ".join(hits) + "\n"


def _git(*args: str) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True)


def _show(spec: str) -> str:
    proc = _git("show", "--end-of-options", spec)
    if proc.returncode != 0 or b"\0" in proc.stdout:
        return ""
    return proc.stdout.decode("utf-8", errors="replace")


def _clean_path(spec: str) -> str | None:
    spec = spec.strip()
    if len(spec) >= 2 and spec[0] == '"' and spec[-1] == '"':
        spec = spec[1:-1]
    if spec == "/dev/null":
        return None
    if spec.startswith("a/") or spec.startswith("b/"):
        return spec[2:]
    return spec


def _split_git_paths(line: str) -> tuple[str | None, str | None]:
    rest = line[len("diff --git ") :].strip()
    if " b/" in rest:
        left, right = rest.rsplit(" b/", 1)
        return _clean_path(left), _clean_path("b/" + right)
    cleaned = _clean_path(rest)
    return cleaned, cleaned


def _hunk_text(lines: list[str]) -> str:
    if not lines:
        return ""
    return "\n".join(lines) + "\n"


def parse_unified(diff: str) -> tuple[_RawFile, ...]:
    raws: list[_RawFile] = []
    old_path: str | None = None
    new_path: str | None = None
    added: list[str] = []
    removed: list[str] = []
    old_lines: list[str] = []
    new_lines: list[str] = []
    in_hunk = False
    binary = False
    started = False

    def flush() -> None:
        nonlocal started
        if not started or binary:
            return
        if old_path is None and new_path is None:
            return
        raws.append(
            _RawFile(
                old_path=old_path,
                new_path=new_path,
                added=tuple(added),
                removed=tuple(removed),
                old_hunk=_hunk_text(old_lines),
                new_hunk=_hunk_text(new_lines),
            )
        )

    for line in diff.splitlines():
        if line.startswith("diff --git "):
            flush()
            old_path, new_path = _split_git_paths(line)
            added = []
            removed = []
            old_lines = []
            new_lines = []
            in_hunk = False
            binary = False
            started = True
            continue
        if not started:
            continue
        if line.startswith("rename from "):
            old_path = line[len("rename from ") :].strip()
            continue
        if line.startswith("rename to "):
            new_path = line[len("rename to ") :].strip()
            continue
        if line.startswith("--- "):
            old_path = _clean_path(line[4:])
            continue
        if line.startswith("+++ "):
            new_path = _clean_path(line[4:])
            continue
        if line.startswith("Binary files "):
            binary = True
            in_hunk = False
            continue
        if line.startswith("@@"):
            in_hunk = True
            continue
        if not in_hunk or line.startswith("\\"):
            continue
        if line.startswith("+"):
            content = line[1:]
            added.append(content)
            new_lines.append(content)
        elif line.startswith("-"):
            content = line[1:]
            removed.append(content)
            old_lines.append(content)
        else:
            content = line[1:] if line.startswith(" ") else line
            old_lines.append(content)
            new_lines.append(content)
    flush()
    return tuple(raws)


def _diff_from_raw(raws: tuple[_RawFile, ...], *, git_base: str | None) -> Diff:
    files: list[FileDiff] = []
    for raw in raws:
        path = raw.new_path or raw.old_path or ""
        if git_base is None:
            old_text = raw.old_hunk
            new_text = raw.new_hunk
        else:
            old_text = _show(f"{git_base}:{raw.old_path}") if raw.old_path else ""
            new_text = _show(f"HEAD:{raw.new_path}") if raw.new_path else ""
        files.append(
            FileDiff(
                path=path,
                added=raw.added,
                removed=raw.removed,
                old_text=old_text,
                new_text=new_text,
            )
        )
    return Diff(files=tuple(files))


def load_diff_file(path: Path) -> Diff:
    return _diff_from_raw(parse_unified(path.read_text()), git_base=None)


def load_base(ref: str) -> Diff:
    parsed = _git("rev-parse", "--verify", "--quiet", ref)
    if parsed.returncode != 0 or not parsed.stdout.strip():
        raise MissingRef()
    base = _git("merge-base", ref, "HEAD")
    if base.returncode != 0 or not base.stdout.strip():
        raise MissingRef()
    merge_base = base.stdout.decode().strip()
    diff = _git("diff", "--find-renames", merge_base, "HEAD")
    if diff.returncode != 0:
        raise RuntimeError(diff.stderr.decode("utf-8", errors="replace").strip() or "git diff failed")
    text = diff.stdout.decode("utf-8", errors="replace")
    return _diff_from_raw(parse_unified(text), git_base=merge_base)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="check-one-way-door.py")
    parser.add_argument("--base")
    parser.add_argument("--diff-file")
    args = parser.parse_args(argv)
    if (args.base is None) == (args.diff_file is None):
        parser.error("pass exactly one of --base and --diff-file")
    if args.diff_file is not None:
        diff = load_diff_file(Path(args.diff_file))
    else:
        try:
            diff = load_base(args.base)
        except MissingRef:
            sys.stdout.write("one-way door: no\nreason: missing ref\n")
            return 0
    sys.stdout.write(report(diff))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
