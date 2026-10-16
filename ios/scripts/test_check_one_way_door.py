#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = Path(__file__).resolve().parent / "check-one-way-door.py"


def load():
    spec = importlib.util.spec_from_file_location("check_one_way_door", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


door = load()


def one(**kwargs):
    fields = {
        "path": "ios/Example.swift",
        "added": (),
        "removed": (),
        "old_text": "",
        "new_text": "",
    }
    fields.update(kwargs)
    return door.FileDiff(**fields)


def diff(*files):
    return door.Diff(files=tuple(files))


class DoorTests(unittest.TestCase):
    def test_swiftdata_yes(self) -> None:
        file = one(
            added=("@Model", "    var nickname: String"),
            new_text="@Model\nfinal class SDExtra {\n    var nickname: String\n}\n",
        )
        self.assertEqual(
            door.swiftdata(diff(file)),
            "added @Model in ios/Example.swift; added stored var in ios/Example.swift",
        )

    def test_swiftdata_no(self) -> None:
        file = one(
            added=("    // copy",),
            old_text="@Model\nfinal class SDMed {\n    var name: String\n}\n",
            new_text="@Model\nfinal class SDMed {\n    var name: String\n    // copy\n}\n",
        )
        self.assertIsNone(door.swiftdata(diff(file)))

    def test_backup_v1_yes(self) -> None:
        file = one(
            path="ios/Sources/PeriMediDomain/Models.swift",
            added=("    var strength: String",),
            old_text="struct Medication {\n    var name: String\n}\n",
            new_text="struct Medication {\n    var name: String\n    var strength: String\n}\n",
        )
        self.assertEqual(door.backup_v1(diff(file)), "required wire key: strength")

    def test_backup_v1_no(self) -> None:
        file = one(
            path="ios/Sources/PeriMediDomain/Models.swift",
            added=("    var note: String?",),
            old_text="struct Medication {\n    var name: String\n}\n",
            new_text="struct Medication {\n    var name: String\n    var note: String?\n}\n",
        )
        self.assertIsNone(door.backup_v1(diff(file)))

    def test_widget_snapshot_yes(self) -> None:
        file = one(
            path="ios/PeriMediDoseWidgetSupport/DoseWidgetSnapshot.swift",
            added=('static let appGroupId = "group.app.perimedi.ios"',),
            old_text="enum DoseWidgetSnapshotFile {\n}\n",
            new_text=(
                "enum DoseWidgetSnapshotFile {\n"
                'static let appGroupId = "group.app.perimedi.ios"\n'
                "}\n"
            ),
        )
        self.assertEqual(
            door.widget_snapshot(diff(file)),
            "added widget constant in ios/PeriMediDoseWidgetSupport/DoseWidgetSnapshot.swift",
        )

    def test_widget_snapshot_no(self) -> None:
        file = one(
            added=("    // note",),
            old_text="struct DoseWidgetAck {\n    let id: String\n}\n",
            new_text="struct DoseWidgetAck {\n    let id: String\n    // note\n}\n",
        )
        self.assertIsNone(door.widget_snapshot(diff(file)))

    def test_signing_yes(self) -> None:
        for needle in (
            "PRODUCT_BUNDLE_IDENTIFIER",
            "group.app.perimedi.ios",
            "iCloud.app.perimedi.ios",
        ):
            file = one(path="ios/App.entitlements", added=(needle,), old_text="", new_text=needle + "\n")
            self.assertEqual(
                door.entitlements_privacy_manifest_release_and_signing(diff(file)),
                f"added {needle} in ios/App.entitlements",
            )

    def test_signing_no(self) -> None:
        file = one(path="ios/App.entitlements", added=("SWIFT_VERSION = 5.0",), new_text="SWIFT_VERSION = 5.0\n")
        self.assertIsNone(door.entitlements_privacy_manifest_release_and_signing(diff(file)))

    def test_quote_paths_stay_quiet(self) -> None:
        file = one(
            path="ios/scripts/test_check_one_way_door.py",
            added=("PRODUCT_BUNDLE_IDENTIFIER",),
            new_text="PRODUCT_BUNDLE_IDENTIFIER\n",
        )
        self.assertEqual(door.report(diff(file)), "one-way door: no\nreason: no detector matched\n")


class CliTests(unittest.TestCase):
    def run_script(self, args: list[str]) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )

    def test_sample_diffs(self) -> None:
        model = self.run_script(["--diff-file", "ios/scripts/testdata/one-way-model.diff"])
        self.assertEqual(model.returncode, 0, model.stderr)
        self.assertEqual(
            model.stdout,
            "one-way door: yes\n"
            "reason: swiftdata: added @Model in ios/Fixtures/NotInTheDoorTable.swift; "
            "added stored var in ios/Fixtures/NotInTheDoorTable.swift\n",
        )
        copy = self.run_script(["--diff-file", "ios/scripts/testdata/one-way-copy.diff"])
        self.assertEqual(copy.returncode, 0, copy.stderr)
        self.assertEqual(copy.stdout, "one-way door: no\nreason: no detector matched\n")

    def test_bad_base_warns_and_exits_0(self) -> None:
        proc = self.run_script(["--base", "refs/does-not-exist"])
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout, "::warning::missing ref: refs/does-not-exist\n")

    def test_help_says_it_only_warns(self) -> None:
        proc = self.run_script(["--help"])
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("only warns", proc.stdout)
        self.assertIn("SwiftData", proc.stdout)


if __name__ == "__main__":
    unittest.main()
