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
