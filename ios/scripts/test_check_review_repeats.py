#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = Path(__file__).resolve().parent / "check-review-repeats.py"

DIALOG = 'languageCode == .german ? "TT.MM.JJJJ" : "YYYY-MM-DD"'
DECIMAL = 'replacingOccurrences(of: ".", with: ",")'
GLUE = ("10 minutes", "10 Minuten", "4. April", "Mar 7")
DIALOG_PATH = "ios/PeriMedi/Features/Sheets/DialogChrome.swift"
DOSE_PATH = "ios/Sources/PeriMediDomain/DoseUnitCopy.swift"
L10N_PATH = "ios/PeriMedi/App/L10n.swift"
UI_PATH = "ios/PeriMediUITests/AppProof.swift"


def load():
    spec = importlib.util.spec_from_file_location("check_review_repeats", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


repeats = load()


def hunk(path: str, added: list[str], removed: list[str] | None = None) -> str:
    lines = [
        f"diff --git a/{path} b/{path}",
        f"--- a/{path}",
        f"+++ b/{path}",
        "@@ -1 +1 @@",
    ]
    for line in removed or []:
        lines.append(f"-{line}")
    for line in added:
        lines.append(f"+{line}")
    return "\n".join(lines) + "\n"


class RepeatTests(unittest.TestCase):
    def test_dialog_placeholder_reports_language_and_date(self) -> None:
        problems = repeats.repeat_problems(hunk(DIALOG_PATH, [DIALOG]))
        self.assertEqual(
            problems,
            [
                f"{DIALOG_PATH}: use app.t for both languages. Found a language-code string.",
                f"{DIALOG_PATH}: use DateCopy for an empty date. Found 'YYYY-MM-DD'.",
            ],
        )

    def test_decimal_swap_reports_dose_unit_copy(self) -> None:
        problems = repeats.repeat_problems(hunk(DOSE_PATH, [DECIMAL]))
        self.assertEqual(
            problems,
            [
                f"{DOSE_PATH}: use DoseUnitCopy with the app language. Found a decimal-point swap."
            ],
        )

    def test_l10n_glue_reports_four_sentences(self) -> None:
        problems = repeats.repeat_problems(hunk(L10N_PATH, list(GLUE)))
        self.assertEqual(
            problems,
            [
                f"{L10N_PATH}: use U+00A0 between the number and the word. Found {matched!r}."
                for matched in GLUE
            ],
        )

    def test_nbsp_and_near_misses_are_clean(self) -> None:
        lines = [
            "10\u00a0minutes",
            "10\u00a0Minuten",
            "4.\u00a0April",
            "Mar\u00a07",
            "10\\u{00A0}minutes",
            "10\\u00a0Minuten",
            "Mar 2026",
            "Sept 7",
            "10  minutes",
            "10\tminutes",
            "4. Mais",
        ]
        self.assertEqual(repeats.repeat_problems(hunk(L10N_PATH, lines)), [])

    def test_ui_tests_and_removed_lines_are_quiet(self) -> None:
        bad = [DIALOG, DECIMAL, *GLUE]
        text = (
            hunk(UI_PATH, bad)
            + hunk(L10N_PATH, [], bad)
            + hunk(DIALOG_PATH, [], bad)
            + hunk(DOSE_PATH, [], [DECIMAL])
        )
        self.assertEqual(repeats.repeat_problems(text), [])


class CliTests(unittest.TestCase):
    def run_script(self, args: list[str]) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )

    def test_diff_file_exits_1(self) -> None:
        with tempfile.NamedTemporaryFile("w", suffix=".diff", delete=False, encoding="utf-8") as handle:
            handle.write(hunk(DIALOG_PATH, [DIALOG]))
            name = handle.name
        proc = self.run_script(["--diff-file", name])
        self.assertEqual(proc.returncode, 1, proc.stderr)
        self.assertIn(
            f"{DIALOG_PATH}: use DateCopy for an empty date. Found 'YYYY-MM-DD'.",
            proc.stdout,
        )

    def test_base_and_default_exit_0(self) -> None:
        based = self.run_script(["--base", "origin/main"])
        self.assertEqual(based.returncode, 0, based.stderr)
        self.assertEqual(based.stdout, "")
        default = self.run_script([])
        self.assertEqual(default.returncode, 0, default.stderr)
        self.assertEqual(default.stdout, "")

    def test_missing_ref_exits_1(self) -> None:
        proc = self.run_script(["--base", "origin/does-not-exist"])
        self.assertEqual(proc.returncode, 1, proc.stdout)
        self.assertEqual(proc.stdout, "")
        self.assertIn("origin/does-not-exist", proc.stderr)

    def test_both_flags_exit_2(self) -> None:
        proc = self.run_script(["--base", "origin/main", "--diff-file", "x.diff"])
        self.assertEqual(proc.returncode, 2, proc.stderr)


if __name__ == "__main__":
    unittest.main()
