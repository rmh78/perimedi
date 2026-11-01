#!/usr/bin/env python3
"""A green nightly is one successful ci.yml run for this SHA.

A scheduled run counts. A workflow_dispatch run counts only when its title is
nightly, which is the run this workflow starts. A failed run, a cancelled run,
and a manual dispatch do not count.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys

NIGHTLY_TITLE = "nightly"


def counts_as_nightly(run: dict) -> bool:
    if run.get("conclusion") != "success":
        return False
    if run.get("event") == "schedule":
        return True
    return (
        run.get("event") == "workflow_dispatch"
        and run.get("display_title") == NIGHTLY_TITLE
    )


def prior_success(runs: list, sha: str) -> str | None:
    for run in runs:
        if run.get("head_sha") != sha:
            continue
        if not counts_as_nightly(run):
            continue
        url = run.get("html_url")
        if isinstance(url, str) and url:
            return url
    return None


def fetch_runs(repo: str, sha: str) -> list:
    raw = subprocess.check_output(
        [
            "gh",
            "api",
            f"repos/{repo}/actions/workflows/ci.yml/runs"
            f"?head_sha={sha}&status=success&per_page=100",
        ],
        text=True,
    )
    payload = json.loads(raw)
    runs = payload.get("workflow_runs")
    if not isinstance(runs, list):
        raise RuntimeError("workflow_runs missing")
    return runs


def write_output(skip: bool) -> None:
    path = os.environ.get("GITHUB_OUTPUT")
    if not path:
        return
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(f"skip={'true' if skip else 'false'}\n")


def main() -> int:
    mode = os.environ.get("NIGHTLY_MODE", "schedule")
    sha = os.environ.get("NIGHTLY_SHA", "")
    if mode == "dispatch":
        print("nightly dispatch runs the suite")
        write_output(False)
        return 0
    if not sha:
        print("nightly lookup missing NIGHTLY_SHA")
        write_output(False)
        return 1 if mode == "check" else 0
    repo = os.environ.get("GITHUB_REPOSITORY", "rmh78/perimedi")
    try:
        runs = fetch_runs(repo, sha)
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError, RuntimeError) as exc:
        print(f"nightly lookup failed {exc}")
        write_output(False)
        return 1 if mode == "check" else 0
    url = prior_success(runs, sha)
    if url:
        print(f"nightly already green {url}")
        write_output(True)
        return 0
    print(f"nightly has no green run for {sha}")
    write_output(mode == "check")
    return 1 if mode == "check" else 0


if __name__ == "__main__":
    sys.exit(main())
