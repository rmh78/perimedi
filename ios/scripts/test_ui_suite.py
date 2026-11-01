#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

import ui_suite

ROOT = Path(__file__).resolve().parents[2]
CI = ROOT / ".github/workflows/ci.yml"
SMOKE_LINE = (
    "PERIMEDI_UI_SUITE: ${{ github.event_name == 'pull_request' && 'smoke' || 'full' }}"
)
BRANCH_FULL = (
    "if: github.event_name == 'workflow_dispatch' && github.ref != 'refs/heads/main'"
)


def _main_is_red():
    scripts = str(ROOT / ".github/scripts")
    if scripts not in sys.path:
        sys.path.insert(0, scripts)
    path = ROOT / ".github/scripts/test_main_is_red.py"
    spec = importlib.util.spec_from_file_location("test_main_is_red", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class UiSuiteTests(unittest.TestCase):
    def test_smoke_allowlist_keeps_unit_tests(self) -> None:
        self.assertEqual(
            ui_suite.args("smoke"),
            [
                "-only-testing:PeriMediUITests/RequiredJourneyTests/testEnglishSmoke",
                "-only-testing:PeriMediTests",
            ],
        )

    def test_full_discovers_the_scheme(self) -> None:
        self.assertEqual(ui_suite.args("full"), [])

    def test_unknown_suite_exits(self) -> None:
        with self.assertRaises(SystemExit):
            ui_suite.args("nope")

    def test_pull_request_selects_smoke_and_other_events_select_full(self) -> None:
        text = CI.read_text(encoding="utf-8")
        self.assertIn(SMOKE_LINE, text)
        self.assertIn(BRANCH_FULL, text)
        self.assertIn("PERIMEDI_UI_SUITE: full", text)
        self.assertFalse((ROOT / ".github/workflows/ui-full.yml").exists())
        self.assertIn(
            "always() && steps.ui-build-cache.outputs.cache-hit != 'true' && steps.build-ok.outputs.ok == 'true'",
            text,
        )
        self.assertNotIn("github.event_name != 'pull_request'", text)

    def test_locked_job_ifs_are_unchanged(self) -> None:
        red = _main_is_red()
        text = CI.read_text(encoding="utf-8")
        self.assertEqual(
            red._jobs_with_exact_if(text, red._FORCE_RED_GUARD),
            ["openspec", "domain", "ui"],
        )


if __name__ == "__main__":
    unittest.main()
