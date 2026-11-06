#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import inspect
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = Path(__file__).resolve().parent / "check-design-system.py"


def load():
    spec = importlib.util.spec_from_file_location("check_design_system", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


design = load()

PATH = "ios/PeriMedi/Features/Cycle/CycleView.swift"


def key(kind: str, excerpt: str, path: str = PATH):
    return (path, kind, excerpt)


class DesignTests(unittest.TestCase):
    def test_equal_multisets_pass_when_mainline_is_at_least_as_large(self) -> None:
        found = {key("hex", "#fff"): 1}
        self.assertEqual(design.judge(found, found, {key("hex", "#fff"): 2}), ())
        self.assertEqual(design.judge(found, found, found), ())

    def test_extra_found_key_is_new_and_extra_baseline_key_is_stale(self) -> None:
        kept = key("hex", "#fff")
        extra = key("hex", "#abc")
        new = design.judge({kept: 1, extra: 1}, {kept: 1}, {kept: 1})
        self.assertTrue(any(line.startswith("new violation") for line in new))
        self.assertTrue(any("Do not add a baseline line." in line for line in new))
        stale = design.judge({kept: 1}, {kept: 1, extra: 1}, {kept: 1, extra: 1})
        self.assertTrue(any(line.startswith("stale baseline") for line in stale))
        self.assertTrue(any("delete the line or lower the count." in line for line in stale))

    def test_same_tree_still_fails_when_the_baseline_grew(self) -> None:
        row = {key("font-literal", ".system(size: 11)"): 2}
        mainline = {key("font-literal", ".system(size: 11)"): 1}
        messages = design.judge(row, row, mainline)
        self.assertTrue(any("grew" in line for line in messages))

    def test_a_lower_baseline_count_passes_when_the_tree_matches(self) -> None:
        row = {key("hex", "#fff"): 1}
        mainline = {key("hex", "#fff"): 4, key("hex", "#abc"): 1}
        self.assertEqual(design.judge(row, row, mainline), ())

    def test_missing_mainline_passes_only_when_found_matches_baseline(self) -> None:
        row = {key("hex", "#fff"): 1}
        self.assertEqual(design.judge(row, row, None), ())
        messages = design.judge({key("hex", "#fff"): 2}, row, None)
        self.assertTrue(any(line.startswith("new violation") for line in messages))

    def test_unsorted_duplicate_zero_unknown_and_tokens_paths_raise(self) -> None:
        good = "ios/PeriMedi/A.swift\thex\t#fff\t1\n"
        later = "ios/PeriMedi/B.swift\thex\t#fff\t1\n"
        samples = (
            later + good,
            good + good,
            "ios/PeriMedi/A.swift\thex\t#fff\t0\n",
            "ios/PeriMedi/A.swift\tspace-literal\tspacing: 8\t1\n",
            "ios/Packages/PeriDesign/Sources/PeriDesign/Tokens/PeriColor.swift\thex\t#fffafb\t1\n",
            "ios/Sources/PeriMediDomain/MedColors.swift\thex\t#fff\t1\n",
        )
        for text in samples:
            with self.subTest(text=text):
                with self.assertRaises(ValueError):
                    design.parse_baseline(text)

    def test_hex_color_init_and_font_literals(self) -> None:
        source = """
        let period = "#9f1239"
        let spaced = "  #9F1239  "
        let lane = Color(hex: lane.color)
        let wash = Color(red: 232 / 255, green: 90 / 255, blue: 132 / 255)
        Text("A").font(.system(size: 11, weight: .bold))
        Text("B").font(.subheadline)
        let measured = UIFont.systemFont(ofSize: subheadlineSize)
        let scaled = UIFont.systemFont(ofSize: subheadlineSize * fit.scale)
        let fixed = UIFont.systemFont(ofSize: 15)
        Text("C").font(Font.custom("Palatino-Bold", size: 44))
        // "#abcdef"
        /* "#112233" */
        // .system(size: 9)
        let mentioned = ".system(size: 11)"
        .padding(12)
        .padding(.horizontal, 4)
        spacing: 8
        cornerRadius: 28
        let short = "#fff"
        let eight = "#aabbccdd"
        let five = "#abcde"
        let mixed = "\\(name)"
        Text("Z").font(.system(size: 12))
        """
        found = design.violations_in(PATH, source)
        self.assertEqual(
            found,
            {
                key("hex", "#9f1239"): 2,
                key("hex", "#fff"): 1,
                key("hex", "#aabbccdd"): 1,
                key("color-init", "Color(red:"): 1,
                key("font-literal", ".system(size: 11)"): 1,
                key("font-literal", ".system(size: 12)"): 1,
                key("font-literal", "UIFont.systemFont(ofSize: 15)"): 1,
                key("font-literal", ".custom("): 1,
            },
        )
        self.assertNotIn("space-literal", {kind for _, kind, _ in found})
        self.assertNotIn("radius-literal", {kind for _, kind, _ in found})

    def test_render_round_trip_is_sorted(self) -> None:
        found = {
            ("ios/PeriMedi/B.swift", "hex", "#fff"): 1,
            ("ios/PeriMedi/A.swift", "font-literal", ".system(size: 11)"): 2,
        }
        text = design.render_baseline(found)
        self.assertEqual(
            text,
            "ios/PeriMedi/A.swift\tfont-literal\t.system(size: 11)\t2\n"
            "ios/PeriMedi/B.swift\thex\t#fff\t1\n",
        )
        self.assertEqual(design.parse_baseline(text), found)
        self.assertEqual(design.render_baseline({}), "")
        self.assertEqual(design.parse_baseline(""), {})

    def test_no_function_takes_a_destination_path(self) -> None:
        source = SCRIPT.read_text(encoding="utf-8")
        self.assertNotIn("write_text", source)
        self.assertNotIn("write_bytes", source)
        self.assertNotIn("open(", source)
        for name, fn in inspect.getmembers(design, inspect.isfunction):
            for param in inspect.signature(fn).parameters:
                lowered = param.lower()
                self.assertNotIn("dest", lowered, name)
                self.assertNotIn("output", lowered, name)

    def test_linkage_needs_the_package_twice(self) -> None:
        self.assertTrue(design.linkage_errors("productName = PeriMedi"))
        once = "Packages/PeriDesign\nproductName = PeriDesign;\n"
        self.assertTrue(design.linkage_errors(once))
        twice = once + "productName = PeriDesign;\n"
        self.assertEqual(design.linkage_errors(twice), ())


if __name__ == "__main__":
    unittest.main()
