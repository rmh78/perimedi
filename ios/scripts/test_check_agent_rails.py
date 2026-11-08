#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from agent_rails import (
    committed_markdown_link_problems,
    docs_folder_problems,
    missing_script_names,
    read_agents,
    tracked_doc_problems,
    unnamed_ui_tests,
)

ROOT = Path(__file__).resolve().parents[2]
RUNNERS = (
    ROOT / ".github/workflows/ci.yml",
    ROOT / ".grok/skills/verify-perimedi/scripts/control-perimedi",
)
CLI = Path(__file__).resolve().parent / "check-agent-rails.py"
UI_CLI = Path(__file__).resolve().parent / "check-ui-test-names.py"
PR_CLI = Path(__file__).resolve().parent / "check-pr-attachments.py"
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


class AttachmentLinkTests(unittest.TestCase):
    def test_docs_folder_outside_app_store(self) -> None:
        self.assertEqual(
            docs_folder_problems(["ios/docs/screens/cycle-empty-en.png"]),
            ["ios/docs/screens/cycle-empty-en.png sits in a docs folder outside docs/app-store."],
        )
        self.assertEqual(docs_folder_problems(["docs/app-store/privacy.md"]), [])

    def test_committed_markdown_rejects_attachment_hosts(self) -> None:
        for host in (
            "github.com/user-attachments",
            "user-images.githubusercontent.com",
        ):
            with self.subTest(host=host):
                problems = committed_markdown_link_problems(f"see https://{host}/a.png")
                self.assertEqual(len(problems), 1)
                self.assertIn(host, problems[0])
                self.assertNotIn("ios/docs", problems[0])

    def test_catalog_path_has_no_markdown_link_problem(self) -> None:
        self.assertEqual(
            committed_markdown_link_problems("see ios/internal/screens/cycle-empty-en.png"),
            [],
        )

    def test_tracked_docs_report_folder_and_markdown_rules(self) -> None:
        paths = [
            "docs/app-store/privacy.md",
            "ios/internal/note.md",
            "ios/docs/screens/cycle-empty-en.png",
        ]
        markdown = {
            "docs/app-store/privacy.md": "https://user-images.githubusercontent.com/a/b.png",
            "ios/internal/note.md": "https://github.com/user-attachments/assets/dead",
        }
        problems = tracked_doc_problems(paths, markdown)
        self.assertIn(
            "ios/docs/screens/cycle-empty-en.png sits in a docs folder outside docs/app-store.",
            problems,
        )
        self.assertIn(
            "docs/app-store/privacy.md: Committed markdown links user-images.githubusercontent.com.",
            problems,
        )
        self.assertIn(
            "ios/internal/note.md: Committed markdown links github.com/user-attachments.",
            problems,
        )

    def test_body_file_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "body.txt"
            path.write_text("https://github.com/user-attachments/assets/dead\n", encoding="utf-8")
            env = os.environ.copy()
            env.pop("GITHUB_EVENT_PATH", None)
            proc = subprocess.run(
                [sys.executable, str(PR_CLI), "--body-file", str(path)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
                env=env,
            )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertTrue(proc.stdout.startswith("ok:"), proc.stdout)

    def test_event_body_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "event.json"
            path.write_text(
                json.dumps(
                    {"pull_request": {"body": "https://user-images.githubusercontent.com/a/b.png"}}
                ),
                encoding="utf-8",
            )
            env = os.environ.copy()
            env["GITHUB_EVENT_PATH"] = str(path)
            proc = subprocess.run(
                [sys.executable, str(PR_CLI)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
                env=env,
            )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertTrue(proc.stdout.startswith("ok:"), proc.stdout)

    def test_cli_real_tree(self) -> None:
        env = os.environ.copy()
        env.pop("GITHUB_EVENT_PATH", None)
        proc = subprocess.run(
            [sys.executable, str(PR_CLI)],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
            env=env,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertTrue(proc.stdout.startswith("ok:"), proc.stdout)


if __name__ == "__main__":
    unittest.main()
