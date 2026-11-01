#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = Path(__file__).resolve().parent / "check-dose-reminder-model.py"
SKILL = ROOT / ".grok/skills/check-dose-reminder/SKILL.md"
CENTER = "ios/PeriMedi/App/DoseReminderCenter.swift"
BRIDGE = "ios/PeriMedi/App/DoseWidgetBridge.swift"
CYCLE = "ios/PeriMedi/Features/Cycle/CycleView.swift"
STORE = "ios/PeriMedi/Persistence/Store.swift"
NEXT = "ios/Sources/PeriMediDomain/NextPendingDose.swift"
INTENT = "ios/PeriMediDoseWidgetSupport/MarkDoseTakenIntent.swift"
REMINDER = "ios/Sources/PeriMediDomain/ReminderLogic.swift"
MODEL = "ios/formal/dose-reminder/DoseReminder.tla"
LEFT_OUT = (
    "Left out: `ReminderLogic.followUpPlan`. "
    "The model does not describe its follow-up schedule."
)
FIX = (
    "update ios/formal/dose-reminder/DoseReminder.tla, "
    "ios/formal/dose-reminder/DoseReminder.cfg, or the Sync commit in "
    ".grok/skills/check-dose-reminder/SKILL.md."
)


def load():
    spec = importlib.util.spec_from_file_location("check_dose_reminder_model", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


model = load()


def hunk(path: str, line: int) -> str:
    return (
        f"diff --git a/{path} b/{path}\n"
        f"--- a/{path}\n"
        f"+++ b/{path}\n"
        f"@@ -{line},1 +{line},1 @@\n"
        "-old\n"
        "+new\n"
    )


def line_of(path: str, needle: str) -> int:
    text = (ROOT / path).read_text(encoding="utf-8")
    return next(number for number, row in enumerate(text.splitlines(), 1) if needle in row)


class DriftTests(unittest.TestCase):
    def setUp(self) -> None:
        self.skill = SKILL.read_text(encoding="utf-8")
        self.covered = model.covered_symbols(self.skill)
        self.store = (ROOT / STORE).read_text(encoding="utf-8")
        self.files = {
            path: ((ROOT / path).read_text(encoding="utf-8"),) * 2
            for path in {symbol.path for symbol in self.covered}
        }

    def test_skill_lists_symbols_and_leaves_follow_up_plan_out(self) -> None:
        self.assertEqual(
            {symbol.path for symbol in self.covered},
            {CENTER, BRIDGE, CYCLE, STORE, NEXT, INTENT},
        )
        self.assertEqual(
            {symbol.name for symbol in self.covered},
            {
                "DoseReminderCenter.markSlotTaken",
                "DoseReminderCenter.markMedicationTaken",
                "DoseReminderCenter.refresh",
                "DoseReminderCenter.reschedule",
                "DoseReminderCenter.cancelNotifications",
                "DoseWidgetBridge.takeFromWidget",
                "DoseWidgetBridge.publish",
                "CycleView.toggleLane",
                "Store.setDoseStatus",
                "NextPendingDose.resolve",
                "MarkTodayMedicationTakenIntent.perform",
            },
        )
        self.assertNotIn("ReminderLogic.followUpPlan", [symbol.name for symbol in self.covered])
        self.assertIn(LEFT_OUT, self.skill)
        self.assertEqual(model.sync_commit(self.skill), "2cdbf5a")
        self.assertEqual(
            model.unresolved(
                self.covered,
                {symbol.path: (ROOT / symbol.path).read_text(encoding="utf-8") for symbol in self.covered},
            ),
            [],
        )

    def test_edit_inside_mark_slot_taken_fails(self) -> None:
        symbol = next(item for item in self.covered if item.name == "DoseReminderCenter.markSlotTaken")
        start, _end = model.symbol_spans(self.files[CENTER][0], symbol)[0]
        problems = model.hunk_problems(
            hunk(CENTER, start), self.covered, self.files, "a124db5", "a124db5"
        )
        self.assertEqual(problems, [f"DoseReminderCenter.markSlotTaken in {CENTER}: {FIX}"])
        cleared = (
            f"diff --git a/{MODEL} b/{MODEL}\n"
            f"--- a/{MODEL}\n"
            f"+++ b/{MODEL}\n"
            "@@ -1,1 +1,1 @@\n"
            "-old\n"
            "+new\n"
        )
        self.assertEqual(
            model.hunk_problems(
                cleared + hunk(CENTER, start),
                self.covered,
                self.files,
                "a124db5",
                "a124db5",
            ),
            [],
        )
        self.assertEqual(
            model.hunk_problems(
                hunk(CENTER, start), self.covered, self.files, "a124db5", "b0b0b0b"
            ),
            [],
        )

    def test_unrelated_store_edit_passes(self) -> None:
        self.assertEqual(
            model.hunk_problems(hunk(STORE, 1), self.covered, self.files, "a124db5", "a124db5"),
            [],
        )

    def test_rename_of_covered_file_fails(self) -> None:
        renamed = "ios/PeriMedi/App/DoseReminderCenterRenamed.swift"
        diff = (
            f"diff --git a/{CENTER} b/{CENTER}\n"
            "deleted file mode 100644\n"
            f"--- a/{CENTER}\n"
            "+++ /dev/null\n"
            "@@ -1,1 +0,0 @@\n"
            "-import Foundation\n"
            f"diff --git a/{renamed} b/{renamed}\n"
            "new file mode 100644\n"
            "--- /dev/null\n"
            f"+++ b/{renamed}\n"
            "@@ -0,0 +1,1 @@\n"
            "+import Foundation\n"
        )
        self.assertEqual(
            model.hunk_problems(diff, self.covered, {}, "a124db5", "a124db5"),
            [f"{CENTER}: renamed or deleted covered file. {FIX}"],
        )

    def test_static_cancel_is_covered(self) -> None:
        line = line_of(CENTER, "func cancelNotifications(ids")
        self.assertEqual(
            model.hunk_problems(hunk(CENTER, line), self.covered, self.files, "a124db5", "a124db5"),
            [f"DoseReminderCenter.cancelNotifications in {CENTER}: {FIX}"],
        )

    def test_follow_up_plan_edit_is_left_out(self) -> None:
        text = (ROOT / REMINDER).read_text(encoding="utf-8")
        line = line_of(REMINDER, "func followUpPlan")
        self.assertEqual(
            model.hunk_problems(
                hunk(REMINDER, line),
                self.covered,
                {REMINDER: (text, text)},
                "a124db5",
                "a124db5",
            ),
            [],
        )


if __name__ == "__main__":
    unittest.main()
