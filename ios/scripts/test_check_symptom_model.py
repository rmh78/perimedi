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


def names(rev: str) -> list[str]:
    proc = subprocess.run(
        ["git", "diff", "--name-only", f"{rev}^", rev],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=True,
    )
    return [line for line in proc.stdout.splitlines() if line]


class DriftTests(unittest.TestCase):
    def setUp(self) -> None:
        self.covered = model.covered_swift(SKILL.read_text(encoding="utf-8"))

    def test_skill_lists_the_covered_files_and_sync_commit(self) -> None:
        self.assertEqual(
            self.covered,
            [
                DIRECTORY,
                STORE,
                "ios/PeriMedi/Persistence/SwiftDataModels.swift",
            ],
        )
        self.assertEqual(model.sync_commit(SKILL.read_text(encoding="utf-8")), "dd69ec0")

    def test_past_sync_fixes_fail_until_the_model_or_commit_moves(self) -> None:
        for rev in PAST:
            changed = names(rev)
            problems = model.drift_problems(changed, self.covered, "parent", "parent")
            self.assertIn(f"{DIRECTORY}: {FIX}", problems, rev)
            self.assertIn(f"{STORE}: {FIX}", problems, rev)
            self.assertEqual(
                model.drift_problems(
                    changed + ["ios/formal/symptom-sync/SymptomSync.tla"],
                    self.covered,
                    "parent",
                    "parent",
                ),
                [],
                rev,
            )
            self.assertEqual(
                model.drift_problems(
                    changed + ["ios/formal/symptom-sync/SymptomSync.cfg"],
                    self.covered,
                    "parent",
                    "parent",
                ),
                [],
                rev,
            )
            self.assertEqual(
                model.drift_problems(changed, self.covered, "parent", rev),
                [],
                rev,
            )

    def test_unrelated_diff_is_clean(self) -> None:
        self.assertEqual(
            model.drift_problems(["AGENTS.md"], self.covered, "dd69ec0", "dd69ec0"),
            [],
        )


if __name__ == "__main__":
    unittest.main()
