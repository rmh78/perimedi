#!/usr/bin/env python3
"""Fail when markdown or a pull request body links a user-attachment host."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

from agent_rails import attachment_links

ROOT = Path(__file__).resolve().parents[2]


def committed_markdown() -> list[Path]:
    out = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    paths: list[Path] = []
    for name in out.decode("utf-8").split("\0"):
        if name.endswith(".md"):
            paths.append(ROOT / name)
    return paths


def pull_request_body(event_text: str) -> str | None:
    data = json.loads(event_text)
    if not isinstance(data, dict):
        return None
    pull_request = data.get("pull_request")
    if not isinstance(pull_request, dict):
        return None
    body = pull_request.get("body")
    if not isinstance(body, str):
        return None
    return body


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    problems: list[str] = []
    for path in committed_markdown():
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)
        for problem in attachment_links(text):
            problems.append(f"{rel}: {problem}")

    bodies: list[str] = []
    if "--body-file" in args:
        idx = args.index("--body-file")
        if idx + 1 >= len(args):
            print("check-pr-attachments.py: --body-file needs a path", file=sys.stderr)
            return 2
        bodies.append(Path(args[idx + 1]).read_text(encoding="utf-8"))

    event = os.environ.get("GITHUB_EVENT_PATH")
    if event and Path(event).is_file():
        try:
            body = pull_request_body(Path(event).read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            print(f"pull request body: {event} is not JSON", file=sys.stderr)
            return 1
        if body is not None:
            bodies.append(body)

    for body in bodies:
        for problem in attachment_links(body):
            problems.append(f"pull request body: {problem}")

    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        return 1
    print("ok: no user-attachment links")
    return 0


if __name__ == "__main__":
    sys.exit(main())
