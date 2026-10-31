#!/usr/bin/env python3

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "check-model-twins.py"
LEFT = Path(__file__).resolve().parent / "check-symptom-model.py"
RIGHT = Path(__file__).resolve().parent / "check-dose-reminder-model.py"


class TwinTests(unittest.TestCase):
    def test_real_pair_passes(self) -> None:
        proc = subprocess.run([sys.executable, str(SCRIPT)], text=True, capture_output=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_one_line_logic_drift_fails(self) -> None:
        text = RIGHT.read_text(encoding="utf-8")
        old = "        return 1\n    print("
        self.assertEqual(text.count(old), 1)
        drifted = text.replace(old, "        return 0\n    print(", 1)
        with tempfile.TemporaryDirectory() as raw:
            copy = Path(raw) / "dose.py"
            copy.write_text(drifted, encoding="utf-8")
            proc = subprocess.run(
                [sys.executable, str(SCRIPT), str(LEFT), str(copy)],
                text=True,
                capture_output=True,
            )
        self.assertEqual(proc.returncode, 1, proc.stdout + proc.stderr)


if __name__ == "__main__":
    unittest.main()
