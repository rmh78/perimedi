#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = Path(__file__).resolve().parent / "check-symptom-model.py"
SKILL = ROOT / ".grok/skills/check-symptom-sync/SKILL.md"
DIRECTORY = "ios/Sources/PeriMediDomain/SymptomDirectory.swift"
STORE = "ios/PeriMedi/Persistence/Store.swift"
PAST = ("d6de884", "bfa1f9e", "15356cf")
LEFT_OUT = "Left out: chain flattening in remembering() and terminal()."
FIX = (
    "update ios/formal/symptom-sync/SymptomSync.tla, "
    "ios/formal/symptom-sync/SymptomSync.cfg, or the Sync commit in "
    ".grok/skills/check-symptom-sync/SKILL.md."
)


def load():
    spec = importlib.util.spec_from_file_location("check_symptom_model", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


model = load()


def show(rev: str, path: str) -> str | None:
    proc = subprocess.run(
        ["git", "show", f"{rev}:{path}"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        return None
    return proc.stdout


def rev_diff(rev: str) -> str:
    proc = subprocess.run(
        ["git", "diff", "--no-renames", "-U0", f"{rev}^", rev],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
    )
    return proc.stdout


def hunk(path: str, line: int) -> str:
    return (
        f"diff --git a/{path} b/{path}\n"
        f"--- a/{path}\n"
        f"+++ b/{path}\n"
        f"@@ -{line},1 +{line},1 @@\n"
        "-old\n"
        "+new\n"
    )


class DriftTests(unittest.TestCase):
    def setUp(self) -> None:
        self.skill = SKILL.read_text(encoding="utf-8")
        self.covered = model.covered_symbols(self.skill)
        self.store = (ROOT / STORE).read_text(encoding="utf-8")
        self.files = {STORE: (self.store, self.store)}

    def test_skill_lists_symbols_and_leaves_chain_flattening_out(self) -> None:
        self.assertEqual(
            {symbol.path for symbol in self.covered},
            {
                DIRECTORY,
                STORE,
                "ios/PeriMedi/Persistence/SwiftDataModels.swift",
            },
        )
        self.assertNotIn("RememberedScoreRewrites.remembering", [s.name for s in self.covered])
        self.assertIn(LEFT_OUT, self.skill)
        self.assertEqual(model.sync_commit(self.skill), "dd69ec0")
        self.assertEqual(model.unresolved(self.covered, {
            symbol.path: (ROOT / symbol.path).read_text(encoding="utf-8")
            for symbol in self.covered
        }), [])

    def test_past_sync_fixes_fail_until_the_model_or_commit_moves(self) -> None:
        for rev in PAST:
            diff = rev_diff(rev)
            files = {
                symbol.path: (show(f"{rev}^", symbol.path), show(rev, symbol.path))
                for symbol in self.covered
            }
            problems = model.hunk_problems(diff, self.covered, files, "parent", "parent")
            self.assertTrue(any(DIRECTORY in item and FIX in item for item in problems), rev)
            self.assertTrue(any(STORE in item and FIX in item for item in problems), rev)
            for model_path in (
                "ios/formal/symptom-sync/SymptomSync.tla",
                "ios/formal/symptom-sync/SymptomSync.cfg",
            ):
                self.assertEqual(
                    model.hunk_problems(
                        f"diff --git a/{model_path} b/{model_path}\n" + diff,
                        self.covered,
                        files,
                        "parent",
                        "parent",
                    ),
                    [],
                    rev,
                )
            self.assertEqual(
                model.hunk_problems(diff, self.covered, files, "parent", rev),
                [],
                rev,
            )

    def test_unrelated_store_edit_passes(self) -> None:
        self.assertEqual(
            model.hunk_problems(hunk(STORE, 1), self.covered, self.files, "dd69ec0", "dd69ec0"),
            [],
        )

    def test_edit_inside_store_refresh_fails(self) -> None:
        refresh = next(symbol for symbol in self.covered if symbol.name == "Store.refresh")
        start, _end = model.symbol_spans(self.store, refresh)[0]
        problems = model.hunk_problems(
            hunk(STORE, start), self.covered, self.files, "dd69ec0", "dd69ec0"
        )
        self.assertEqual(problems, [f"Store.refresh in {STORE}: {FIX}"])
        mentioned = (
            "diff --git a/.grok/skills/check-symptom-sync/SKILL.md "
            "b/.grok/skills/check-symptom-sync/SKILL.md\n"
            "@@ -1,1 +1,1 @@\n"
            "-old\n"
            "+see ios/formal/symptom-sync/SymptomSync.tla\n"
        )
        self.assertEqual(
            model.hunk_problems(
                mentioned + hunk(STORE, start),
                self.covered,
                self.files,
                "dd69ec0",
                "dd69ec0",
            ),
            [f"Store.refresh in {STORE}: {FIX}"],
        )

    def test_rename_of_covered_file_fails(self) -> None:
        renamed = "ios/PeriMedi/Persistence/StoreRenamed.swift"
        diff = (
            f"diff --git a/{STORE} b/{STORE}\n"
            "deleted file mode 100644\n"
            f"--- a/{STORE}\n"
            "+++ /dev/null\n"
            "@@ -1,1 +0,0 @@\n"
            "-import CoreData\n"
            f"diff --git a/{renamed} b/{renamed}\n"
            "new file mode 100644\n"
            "--- /dev/null\n"
            f"+++ b/{renamed}\n"
            "@@ -0,0 +1,1 @@\n"
            "+import CoreData\n"
        )
        problems = model.hunk_problems(diff, self.covered, {}, "dd69ec0", "dd69ec0")
        self.assertEqual(problems, [f"{STORE}: renamed or deleted covered file. {FIX}"])

    def test_remembering_edit_is_left_out(self) -> None:
        text = (ROOT / DIRECTORY).read_text(encoding="utf-8")
        line = next(
            number
            for number, row in enumerate(text.splitlines(), 1)
            if "func remembering" in row
        )
        self.assertEqual(
            model.hunk_problems(
                hunk(DIRECTORY, line),
                self.covered,
                {DIRECTORY: (text, text)},
                "dd69ec0",
                "dd69ec0",
            ),
            [],
        )


if __name__ == "__main__":
    unittest.main()
