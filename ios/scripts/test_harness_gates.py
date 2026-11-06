#!/usr/bin/env python3

from __future__ import annotations

import os
import subprocess
import sys
import unittest
from pathlib import Path

from harness_gates import FEATURES, GateCheck, agent_checks, github_notice, run_gate

ROOT = Path(__file__).resolve().parents[2]


class Recording:
    def __init__(self, codes: dict[str, int] | None = None) -> None:
        self.codes = codes or {}
        self.seen: list[GateCheck] = []

    def __call__(self, check: GateCheck) -> tuple[int, str, str]:
        self.seen.append(check)
        if check.blocks:
            return self.codes.get(check.script, 0), "ok\n", ""
        return self.codes.get(check.script, 0), "one-way door: yes\nreason: a::b\n", ""


class GateTableTests(unittest.TestCase):
    def test_features_runs_the_five_proof_checks(self) -> None:
        rec = Recording()
        self.assertEqual(run_gate(FEATURES, run=rec), 0)
        self.assertEqual(
            [(check.script, check.args, check.blocks) for check in rec.seen],
            [
                ("check-feature-map.py", (), True),
                ("check-feature-layout.py", (), True),
                ("check-ui-coverage.py", ("--fail-uncovered",), True),
                ("check-ui-test-names.py", (), True),
                ("check-screen-catalog.py", (), True),
            ],
        )

    def test_agent_runs_hygiene_then_a_nonblocking_door(self) -> None:
        rec = Recording()
        self.assertEqual(run_gate(agent_checks("origin/topic"), run=rec), 0)
        self.assertEqual(
            [(check.script, check.args, check.blocks) for check in rec.seen],
            [
                ("check-agent-rails.py", (), True),
                ("check-review-repeats.py", ("--base", "origin/topic"), True),
                ("check-pr-attachments.py", (), True),
                ("check-one-way-door.py", ("--base", "origin/topic"), False),
            ],
        )

    def test_a_blocking_failure_still_runs_the_rest(self) -> None:
        rec = Recording({"check-agent-rails.py": 1})
        self.assertEqual(run_gate(agent_checks("origin/main"), run=rec), 1)
        self.assertEqual(
            [check.script for check in rec.seen],
            [
                "check-agent-rails.py",
                "check-review-repeats.py",
                "check-pr-attachments.py",
                "check-one-way-door.py",
            ],
        )

    def test_door_status_does_not_fail_the_gate(self) -> None:
        rec = Recording({"check-one-way-door.py": 2})
        self.assertEqual(run_gate(agent_checks("origin/main"), run=rec), 0)

    def test_notice_matches_the_pull_request_line(self) -> None:
        os.environ["GITHUB_ACTIONS"] = "true"
        self.addCleanup(os.environ.pop, "GITHUB_ACTIONS", None)
        notice = github_notice("one-way door: yes\nreason: a::b\nsecond\n")
        self.assertEqual(notice, "::notice title=One-way door::ab second ")

    def test_notice_stays_off_outside_actions(self) -> None:
        os.environ.pop("GITHUB_ACTIONS", None)
        self.assertIsNone(github_notice("one-way door: yes\nreason: model\n"))

    def test_clean_tree_gates_exit_0(self) -> None:
        for script, args in (
            ("check-features.py", []),
            ("check-agent.py", ["--base", "origin/main"]),
        ):
            with self.subTest(script=script):
                proc = subprocess.run(
                    [sys.executable, str(ROOT / "ios/scripts" / script), *args],
                    cwd=ROOT,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
                self.assertNotIn("::notice", proc.stdout)


if __name__ == "__main__":
    unittest.main()
