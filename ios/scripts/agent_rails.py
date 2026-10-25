"""Pure checks for agent-facing rails. Callers pass text and paths."""

from __future__ import annotations

import re
from pathlib import Path

_SCRIPT = re.compile(
    r"""python3\s+(?:"\$ROOT"/|"\$ROOT/|\$ROOT/)?"""
    r"""((?:ios/scripts|\.github/scripts)/[\w./-]+\.py)(?![\w./-])"""
)

_LITERALS = (
    "collect-test-diagnostics",
    "simctl diagnose",
    "force_red",
)


def read_agents(root: Path) -> str:
    for name in ("Agents.md", "AGENTS.md"):
        path = root / name
        if path.is_file():
            return path.read_text(encoding="utf-8")
    raise FileNotFoundError(root / "Agents.md")


_UI_TEST = re.compile(r"\bfunc\s+(test\w*)\s*\(")


def unnamed_ui_tests(swift_text: str, doc_text: str) -> list[str]:
    problems: list[str] = []
    seen: list[str] = []
    for match in _UI_TEST.finditer(swift_text):
        name = match.group(1)
        if name in seen:
            continue
        seen.append(name)
        if name not in doc_text:
            problems.append(
                f"UI test {name} is not named in Agents.md or features/. "
                "Add the method name next to the journey that runs it."
            )
    return problems


def missing_script_names(runner_text: str, agents_text: str) -> list[str]:
    problems: list[str] = []
    seen: list[str] = []
    for match in _SCRIPT.finditer(runner_text):
        basename = Path(match.group(1)).name
        if basename in seen:
            continue
        seen.append(basename)
        if basename not in agents_text:
            problems.append(
                f"Agents.md does not name {basename}. "
                "Add one line in the ids or Pieces list so the next agent runs it."
            )
    for literal in _LITERALS:
        if literal in runner_text and literal not in agents_text:
            problems.append(
                f'Agents.md does not contain "{literal}". '
                "Add it to the verify or CI paragraph in Agents.md."
            )
    return problems


_ATTACHMENT_HOSTS = (
    "github.com/user-attachments",
    "user-images.githubusercontent.com",
)


def attachment_links(text: str) -> list[str]:
    problems: list[str] = []
    for host in _ATTACHMENT_HOSTS:
        if host in text:
            problems.append(
                f"Link host {host} 404s for reviewers. "
                "Commit the PNG under ios/docs/screens/ and link that path."
            )
    return problems
