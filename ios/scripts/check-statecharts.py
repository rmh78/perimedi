#!/usr/bin/env python3
"""Fail when a committed statechart fence drifts from the chart the tool writes."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from tlc import jar

ROOT = Path(__file__).resolve().parents[2]
PLUGIN_COMMIT = "f14452f4630049f721e8871c714eac9596093f03"
PLUGIN_URL = "https://github.com/pstack-ports/grok-pstack.git"
PLUGIN_CACHE = Path.home() / ".cache/perimedi/grok-pstack" / PLUGIN_COMMIT
FENCE = re.compile(r"```mermaid\n(.*?)```", re.S)

# Prose in the doc is not regenerated. Only the mermaid fence is compared.
MODELS = (
    (
        "dose-reminder",
        ROOT / "ios/formal/dose-reminder/DoseReminder.tla",
        ROOT / "ios/formal/dose-reminder/DoseReminder.cfg",
        ROOT / "ios/formal/dose-reminder/view.mjs",
        ROOT / "docs/statecharts/dose-reminder.md",
    ),
    (
        "symptom-sync",
        ROOT / "ios/formal/symptom-sync/SymptomSync.tla",
        ROOT / "ios/formal/symptom-sync/SymptomSync.cfg",
        ROOT / "ios/formal/symptom-sync/view.mjs",
        ROOT / "docs/statecharts/symptom-sync.md",
    ),
)


def norm(text: str) -> str:
    return text.strip("\n") + "\n"


def fence(text: str) -> str | None:
    match = FENCE.search(text)
    if match is None:
        return None
    return norm(match.group(1))


def plugin_dir() -> Path:
    script = PLUGIN_CACHE / "skills/statechart/scripts/statechart"
    if script.is_file():
        rev = subprocess.run(
            ["git", "-C", str(PLUGIN_CACHE), "rev-parse", "HEAD"],
            text=True,
            capture_output=True,
            check=False,
        )
        if rev.stdout.strip() == PLUGIN_COMMIT:
            return PLUGIN_CACHE
    if PLUGIN_CACHE.exists():
        shutil.rmtree(PLUGIN_CACHE)
    PLUGIN_CACHE.mkdir(parents=True)
    init = subprocess.run(["git", "init", "-q"], cwd=PLUGIN_CACHE, text=True, capture_output=True, check=False)
    if init.returncode != 0:
        print(init.stderr.strip() or "git init failed", file=sys.stderr)
        raise SystemExit(2)
    remote = subprocess.run(
        ["git", "remote", "add", "origin", PLUGIN_URL],
        cwd=PLUGIN_CACHE,
        text=True,
        capture_output=True,
        check=False,
    )
    if remote.returncode != 0:
        print(remote.stderr.strip() or "git remote add failed", file=sys.stderr)
        raise SystemExit(2)
    fetched = subprocess.run(
        ["git", "fetch", "--depth", "1", "origin", PLUGIN_COMMIT],
        cwd=PLUGIN_CACHE,
        text=True,
        capture_output=True,
        check=False,
    )
    if fetched.returncode != 0:
        print(fetched.stderr.strip() or "git fetch failed", file=sys.stderr)
        raise SystemExit(2)
    checked = subprocess.run(
        ["git", "checkout", "--quiet", "FETCH_HEAD"],
        cwd=PLUGIN_CACHE,
        text=True,
        capture_output=True,
        check=False,
    )
    if checked.returncode != 0:
        print(checked.stderr.strip() or "git checkout failed", file=sys.stderr)
        raise SystemExit(2)
    return PLUGIN_CACHE


def generate(tool: Path, java: str, jar_path: Path, spec: Path, cfg: Path, view: Path, out: Path) -> int:
    env = os.environ.copy()
    env["TLA2TOOLS"] = str(jar_path)
    env["JAVA"] = java
    try:
        proc = subprocess.run(
            [str(tool), str(spec), "--config", str(cfg), "--view", str(view), "--out", str(out)],
            text=True,
            capture_output=True,
            timeout=180,
            check=False,
            env=env,
        )
    except subprocess.TimeoutExpired:
        print(f"statechart timed out for {spec.name}", file=sys.stderr)
        return 2
    if proc.returncode not in {0, 1}:
        sys.stderr.write(proc.stdout)
        sys.stderr.write(proc.stderr)
        return 2
    return proc.returncode


def main() -> int:
    java = shutil.which("java")
    if java is None:
        print("java is not on PATH", file=sys.stderr)
        return 2
    tool = plugin_dir() / "skills/statechart/scripts/statechart"
    if not tool.is_file():
        print("statechart tool is missing from the pinned plugin", file=sys.stderr)
        return 2
    jar_path = jar()
    failed = False
    for name, spec, cfg, view, doc in MODELS:
        if not spec.is_file() or not cfg.is_file() or not view.is_file() or not doc.is_file():
            print(f"missing inputs for {name}", file=sys.stderr)
            return 2
        with tempfile.TemporaryDirectory(prefix=f"statechart-{name}-") as raw:
            code = generate(tool, java, jar_path, spec, cfg, view, Path(raw))
            if code == 2:
                return 2
            chart_path = Path(raw) / "chart.mmd"
            committed = fence(doc.read_text(encoding="utf-8"))
            if chart_path.is_file():
                generated = norm(chart_path.read_text(encoding="utf-8"))
                if committed != generated:
                    print(f"{name}: mermaid fence does not match chart.mmd", file=sys.stderr)
                    failed = True
                    continue
                print(f"ok: {name} fence matches")
                continue
            if committed is not None:
                print(f"{name}: doc has a fence and the tool wrote no chart.mmd", file=sys.stderr)
                failed = True
                continue
            print(f"ok: {name} has no chart")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
