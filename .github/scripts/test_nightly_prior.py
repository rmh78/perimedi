#!/usr/bin/env python3
from __future__ import annotations

import unittest
from pathlib import Path

import nightly_prior as prior
from test_main_is_red import _FORCE_RED_GUARD, _jobs_with_exact_if

ROOT = Path(__file__).resolve().parents[2]
SHA = "abc"
URL = "https://github.com/rmh78/perimedi/actions/runs/41301256609"


def run(event: str, conclusion: str, title: str = "ci", sha: str = SHA, url: str = URL) -> dict:
    return {
        "head_sha": sha,
        "event": event,
        "conclusion": conclusion,
        "display_title": title,
        "html_url": url,
    }


class PriorTest(unittest.TestCase):
    def test_scheduled_success_counts(self) -> None:
        self.assertEqual(prior.prior_success([run("schedule", "success")], SHA), URL)

    def test_failed_and_cancelled_do_not_count(self) -> None:
        runs = [run("schedule", "failure"), run("schedule", "cancelled")]
        self.assertIsNone(prior.prior_success(runs, SHA))

    def test_manual_dispatch_does_not_count(self) -> None:
        self.assertIsNone(prior.prior_success([run("workflow_dispatch", "success", "ci")], SHA))

    def test_nightly_titled_dispatch_counts(self) -> None:
        found = prior.prior_success(
            [run("workflow_dispatch", "success", prior.NIGHTLY_TITLE)],
            SHA,
        )
        self.assertEqual(found, URL)

    def test_other_sha_does_not_count(self) -> None:
        self.assertIsNone(prior.prior_success([run("schedule", "success", sha="other")], SHA))

    def test_empty_list_is_none(self) -> None:
        self.assertIsNone(prior.prior_success([], SHA))

    def test_first_url_wins(self) -> None:
        first = "https://github.com/rmh78/perimedi/actions/runs/1"
        runs = [
            run("schedule", "success", url=first),
            run("schedule", "success", url=URL),
        ]
        self.assertEqual(prior.prior_success(runs, SHA), first)

    def test_blank_url_is_skipped(self) -> None:
        runs = [run("schedule", "success", url=""), run("schedule", "success")]
        self.assertEqual(prior.prior_success(runs, SHA), URL)


class WiringTest(unittest.TestCase):
    def test_cron_lives_only_on_nightly(self) -> None:
        ci = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
        nightly = (ROOT / ".github/workflows/nightly.yml").read_text(encoding="utf-8")
        self.assertIn("cron: '17 4 * * *'", nightly)
        self.assertNotIn("\n  schedule:\n", ci)
        self.assertIn("steps.prior.outputs.skip != 'true'", nightly)
        self.assertIn("-f nightly=true", nightly)
        self.assertIn("NIGHTLY_MODE", nightly)
        self.assertIn("nightly:", ci)
        self.assertIn("&& 'nightly' ||", ci)
        self.assertEqual(
            _jobs_with_exact_if(ci, _FORCE_RED_GUARD),
            ["openspec", "domain", "ui"],
        )


if __name__ == "__main__":
    unittest.main()
