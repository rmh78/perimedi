#!/usr/bin/env python3

from __future__ import annotations

import os
import subprocess
import sys
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "ios/scripts"

Runner = Callable[["GateCheck"], tuple[int, str, str]]


@dataclass(frozen=True)
class GateCheck:
    script: str
    args: tuple[str, ...] = ()
    blocks: bool = True


FEATURES: tuple[GateCheck, ...] = (
    GateCheck("check-feature-map.py"),
    GateCheck("check-feature-layout.py"),
    GateCheck("check-ui-coverage.py", ("--fail-uncovered",)),
    GateCheck("check-ui-test-names.py"),
    GateCheck("check-screen-catalog.py"),
)


def agent_checks(base: str) -> tuple[GateCheck, ...]:
    base_arg = ("--base", base)
    return (
        GateCheck("check-agent-rails.py"),
        GateCheck("check-review-repeats.py", base_arg),
        GateCheck("check-pr-attachments.py"),
        GateCheck("check-design-system.py", base_arg),
        GateCheck("check-one-way-door.py", base_arg, blocks=False),
    )


def github_notice(stdout: str) -> str | None:
    if os.environ.get("GITHUB_ACTIONS") != "true":
        return None
    first, _, rest = stdout.partition("\n")
    if first != "one-way door: yes":
        return None
    marker = "reason: "
    reason = rest[len(marker) :] if rest.startswith(marker) else rest
    reason = reason.replace("\n", " ").replace("::", "")
    return f"::notice title=One-way door::{reason[:400]}"


def _execute(check: GateCheck) -> tuple[int, str, str]:
    proc = subprocess.run(
        [sys.executable, str(SCRIPTS / check.script), *check.args],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    return proc.returncode, proc.stdout, proc.stderr


def _write(stream, text: str) -> None:
    if text:
        stream.write(text)
        if not text.endswith("\n"):
            stream.write("\n")


def run_gate(checks: Sequence[GateCheck], *, run: Runner | None = None) -> int:
    execute = run or _execute
    failed = False
    for check in checks:
        code, out, err = execute(check)
        label = " ".join((check.script, *check.args))
        print(f"+ {label}", flush=True)
        _write(sys.stdout, out)
        _write(sys.stderr, err)
        if not check.blocks:
            notice = github_notice(out)
            if notice is not None:
                print(notice, flush=True)
            continue
        if code != 0:
            failed = True
    return 1 if failed else 0
