#!/usr/bin/env python3

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

from agent_rails import missing_script_names, read_agents, unnamed_ui_tests

ROOT = Path(__file__).resolve().parents[2]
RUNNERS = (
    ROOT / ".github/workflows/ci.yml",
    ROOT / ".grok/skills/verify-perimedi/scripts/control-perimedi",
)
CLI = Path(__file__).resolve().parent / "check-agent-rails.py"
UI_CLI = Path(__file__).resolve().parent / "check-ui-test-names.py"
UNNAMED_TEST = (
    "UI test testNope is not named in Agents.md or features/. "
    "Add the method name next to the journey that runs it."
)

MISSING = (
    "Agents.md does not name check-not-named.py. "
    "Add one line in the ids or Pieces list so the next agent runs it."
)


def runner_text() -> str:
    return "\n".join(path.read_text(encoding="utf-8") for path in RUNNERS)


class AgentRailsTests(unittest.TestCase):
    def test_unnamed_script_fails(self) -> None:
        problems = missing_script_names(
            "python3 ios/scripts/check-not-named.py\n",
            "Agents.md lists other scripts.\n",
        )
        self.assertEqual(problems, [MISSING])
        self.assertIn("check-not-named.py", problems[0])
        self.assertIn("Agents.md", problems[0])

    def test_named_script_passes(self) -> None:
        problems = missing_script_names(
            "python3 ios/scripts/check-not-named.py\n",
            "Agents.md lists other scripts.\ncheck-not-named.py\n",
        )
        self.assertEqual(problems, [])

    def test_comment_invocation_counts(self) -> None:
        problems = missing_script_names(
            "# python3 ios/scripts/check-not-named.py\n",
            "",
        )
        self.assertEqual(problems, [MISSING])

    def test_root_prefixes_count(self) -> None:
        for runner in (
            'python3 "$ROOT/ios/scripts/check-not-named.py"\n',
            'python3 "$ROOT"/.github/scripts/check-not-named.py\n',
            "python3 $ROOT/ios/scripts/check-not-named.py\n",
        ):
            with self.subTest(runner=runner):
                self.assertEqual(missing_script_names(runner, ""), [MISSING])

    def test_force_red_literal_fails(self) -> None:
        problems = missing_script_names("uses force_red on purpose\n", "CI paragraph\n")
        self.assertEqual(
            problems,
            [
                'Agents.md does not contain "force_red". '
                "Add it to the verify or CI paragraph in Agents.md."
            ],
        )

    def test_force_red_literal_passes_when_named(self) -> None:
        problems = missing_script_names("uses force_red on purpose\n", "force_red\n")
        self.assertEqual(problems, [])

    def test_real_tree_has_no_problems(self) -> None:
        problems = missing_script_names(runner_text(), read_agents(ROOT))
        self.assertEqual(problems, [])

    def test_cli_real_tree(self) -> None:
        proc = subprocess.run(
            [sys.executable, str(CLI)],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertTrue(proc.stdout.startswith("ok:"), proc.stdout)


class UiTestNameTests(unittest.TestCase):
    def test_unnamed_method_fails(self) -> None:
        problems = unnamed_ui_tests("func testNope() {}\n", "Agents.md and features omit it.\n")
        self.assertEqual(problems, [UNNAMED_TEST])
        self.assertIn("testNope", problems[0])

    def test_named_method_passes(self) -> None:
        problems = unnamed_ui_tests("func testNope() {}\n", "The journey runs testNope.\n")
        self.assertEqual(problems, [])

    def test_real_tree_names_every_method(self) -> None:
        swift = "\n".join(
            path.read_text(encoding="utf-8")
            for path in sorted((ROOT / "ios/PeriMediUITests").rglob("*.swift"))
        )
        docs = [read_agents(ROOT)]
        feature_dir = ROOT / ".grok/skills/verify-perimedi/features"
        docs.extend(
            path.read_text(encoding="utf-8")
            for path in sorted(feature_dir.glob("*.md"))
        )
        self.assertEqual(unnamed_ui_tests(swift, "\n".join(docs)), [])

    def test_cli_real_tree(self) -> None:
        proc = subprocess.run(
            [sys.executable, str(UI_CLI)],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertTrue(proc.stdout.startswith("ok:"), proc.stdout)


if __name__ == "__main__":
    unittest.main()
