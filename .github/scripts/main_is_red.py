#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from collections.abc import Mapping, Sequence

JOBS = ("ids", "openspec", "domain", "ui")
VERDICTS = frozenset({"success", "failure", "skipped", "cancelled"})
FAILED = frozenset({"failure", "cancelled"})
TITLE = "main is red"
LABEL = "main-red"
ENV_RESULTS = ("MAIN_IDS", "MAIN_OPENSPEC", "MAIN_DOMAIN", "MAIN_UI")
ENV_REQUIRED = ENV_RESULTS + ("FORCE_RED", "MAIN_RUN_URL", "GITHUB_REPOSITORY", "GH_TOKEN")


def transition(
    results: Sequence[str],
    force: bool,
    open_numbers: Sequence[int],
    run_url: str,
) -> tuple:
    if len(results) != len(JOBS) or any(result not in VERDICTS for result in results):
        return ("hold",)
    failed = tuple(job for job, result in zip(JOBS, results) if result in FAILED)
    ordered = tuple(sorted(open_numbers))
    if failed:
        keeper = ordered[0] if ordered else None
        return ("open", keeper, ordered[1:], failing_body(failed, run_url, force))
    if force or any(result == "skipped" for result in results):
        return ("hold",)
    if ordered:
        return ("close", ordered)
    return ("absent",)


def failing_body(jobs: Sequence[str], run_url: str, force: bool) -> str:
    body = f"Failing jobs: {', '.join(jobs)}\nRun: {run_url}\n"
    if force:
        body += "Drill: force_red\n"
    return body


def green_comment(run_url: str) -> str:
    return f"Main is green.\nRun: {run_url}\n"


def duplicate_comment(keeper: int) -> str:
    return f"Duplicate of #{keeper}."


def red_issue_numbers(payload: str) -> list[int]:
    numbers: list[int] = []
    text = payload.strip()
    if not text:
        return []
    decoder = json.JSONDecoder()
    index = 0
    length = len(text)
    while index < length:
        while index < length and text[index].isspace():
            index += 1
        if index >= length:
            break
        try:
            value, index = decoder.raw_decode(text, index)
        except json.JSONDecodeError as exc:
            raise SystemExit(f"bad issue list: {exc}") from exc
        for row in _rows(value):
            if "pull_request" in row or row.get("title") != TITLE or not _has_label(row):
                continue
            number = row.get("number")
            if type(number) is int:
                numbers.append(number)
    numbers.sort()
    return numbers


def _has_label(row: dict) -> bool:
    labels = row.get("labels")
    if not isinstance(labels, list):
        return False
    for label in labels:
        if label == LABEL or (isinstance(label, dict) and label.get("name") == LABEL):
            return True
    return False


def _rows(value: object) -> list[dict]:
    if isinstance(value, list):
        rows = value
    elif isinstance(value, dict) and "number" in value:
        rows = [value]
    elif isinstance(value, dict):
        message = value.get("message")
        raise SystemExit(message if isinstance(message, str) and message else "bad issue list")
    else:
        raise SystemExit("bad issue list")
    parsed: list[dict] = []
    for row in rows:
        if not isinstance(row, dict):
            raise SystemExit("bad issue list")
        parsed.append(row)
    return parsed


def apply(end: tuple, run_url: str, board) -> None:
    kind = end[0]
    if kind in ("hold", "absent"):
        return
    if kind == "close":
        comment = green_comment(run_url)
        for number in end[1]:
            board.close(number, comment)
        return
    if kind != "open":
        raise SystemExit(f"bad end: {kind}")
    _, keeper, extras, body = end
    if keeper is None:
        created = board.create(body)
        numbers = tuple(sorted(set(board.list_open()) | {created}))
        lowest = numbers[0]
        if lowest != created or len(numbers) > 1:
            board.edit(lowest, body)
        for number in numbers[1:]:
            board.close(number, duplicate_comment(lowest))
        return
    board.edit(keeper, body)
    for number in extras:
        board.close(number, duplicate_comment(keeper))


def parse_env(env: Mapping[str, str]) -> tuple[tuple[str, ...], bool, str, str]:
    missing = [name for name in ENV_REQUIRED if name not in env]
    if missing:
        raise SystemExit(f"missing {', '.join(missing)}")
    blank = [name for name in ("MAIN_RUN_URL", "GITHUB_REPOSITORY", "GH_TOKEN") if env[name] == ""]
    if blank:
        raise SystemExit(f"missing {', '.join(blank)}")
    results = tuple(env[name] for name in ENV_RESULTS)
    bad = [name for name, result in zip(ENV_RESULTS, results) if result not in VERDICTS]
    if bad:
        raise SystemExit(f"bad job result: {', '.join(bad)}")
    force_raw = env["FORCE_RED"]
    if force_raw not in ("true", "false"):
        raise SystemExit(f"bad FORCE_RED: {force_raw!r}")
    return results, force_raw == "true", env["MAIN_RUN_URL"], env["GITHUB_REPOSITORY"]


class GhBoard:
    def __init__(self, repo: str) -> None:
        self.repo = repo

    def list_open(self) -> list[int]:
        text = _gh(
            [
                "api",
                "--paginate",
                f"repos/{self.repo}/issues?state=open&labels={LABEL}&per_page=100",
            ]
        )
        return red_issue_numbers(text)

    def create(self, body: str) -> int:
        args = [
            "issue",
            "create",
            "--repo",
            self.repo,
            "--title",
            TITLE,
        ]
        if self._label_ready():
            args.extend(["--label", LABEL])
        args.append("--body-file")
        text = _gh_body(args, body)
        return _issue_number(text)

    def _label_ready(self) -> bool:
        completed = _run_gh(
            [
                "label",
                "create",
                LABEL,
                "--repo",
                self.repo,
                "--color",
                "B60205",
                "--description",
                "CI owns this issue",
                "--force",
            ]
        )
        if completed.returncode == 0:
            return True
        detail = completed.stderr.strip() or f"exit {completed.returncode}"
        sys.stderr.write(f"warning: gh label create {LABEL} failed: {detail}\n")
        probe = _run_gh(["api", "--silent", f"repos/{self.repo}/labels/{LABEL}"])
        return probe.returncode == 0

    def edit(self, number: int, body: str) -> None:
        _gh_body(
            ["issue", "edit", str(number), "--repo", self.repo, "--body-file"],
            body,
        )

    def close(self, number: int, comment: str) -> None:
        _gh(["issue", "close", str(number), "--repo", self.repo, "--comment", comment])


def _gh_body(args: list[str], body: str) -> str:
    fd, path = tempfile.mkstemp(prefix="main-is-red-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(body)
        return _gh([*args, path])
    finally:
        os.remove(path)


def _run_gh(args: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            ["gh", *args],
            check=False,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        raise SystemExit("gh not found") from None


def _gh(args: list[str]) -> str:
    completed = _run_gh(args)
    if completed.returncode != 0:
        sys.stderr.write(completed.stderr)
        raise SystemExit(completed.returncode or 1)
    return completed.stdout


def _issue_number(text: str) -> int:
    for line in reversed(text.splitlines()):
        match = re.search(r"/issues/(\d+)\s*$", line.strip())
        if match:
            return int(match.group(1))
    raise SystemExit(f"bad issue url: {text.strip()!r}")


def main() -> None:
    results, force, run_url, repo = parse_env(os.environ)
    board = GhBoard(repo)
    apply(transition(results, force, board.list_open(), run_url), run_url, board)


if __name__ == "__main__":
    main()
