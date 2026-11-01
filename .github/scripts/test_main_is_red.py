#!/usr/bin/env python3
from __future__ import annotations

import contextlib
import io
import json
import re
import subprocess
import unittest
from pathlib import Path

import main_is_red as red

URL = "https://github.com/example/perimedi/actions/runs/1"
OK = ("success", "success", "success", "success")
IDS_BODY = f"Failing jobs: ids\nRun: {URL}\n"
GREEN = f"Main is green.\nRun: {URL}\n"


class Board:
    def __init__(self, after_create=None):
        self.creates = []
        self.edits = []
        self.closes = []
        self.after_create = after_create
        self._next = 40

    def create(self, body: str) -> int:
        self._next += 1
        self.creates.append((self._next, body))
        return self._next

    def edit(self, number: int, body: str) -> None:
        self.edits.append((number, body))

    def close(self, number: int, comment: str) -> None:
        self.closes.append((number, comment))

    def list_open(self) -> list[int]:
        if self.after_create is None:
            raise AssertionError("list_open")
        return self.after_create(self.creates[-1][0])


class TransitionTest(unittest.TestCase):
    def test_four_successes_with_no_issues_are_absent(self) -> None:
        self.assertEqual(red.transition(OK, False, [], URL), ("absent",))

    def test_four_successes_close_open_issues_ascending(self) -> None:
        self.assertEqual(red.transition(OK, False, [9, 4], URL), ("close", (4, 9)))

    def test_ids_failure_opens_with_ids_and_url_and_no_drill(self) -> None:
        end = red.transition(("failure", "success", "success", "success"), False, [], URL)
        self.assertEqual(end, ("open", None, (), IDS_BODY))
        self.assertNotIn("Drill:", end[3])

    def test_ids_failure_keeps_lowest_and_closes_the_rest(self) -> None:
        end = red.transition(("failure", "success", "success", "success"), False, [4, 10], URL)
        self.assertEqual(end, ("open", 4, (10,), IDS_BODY))

    def test_cancelled_domain_opens_naming_domain(self) -> None:
        end = red.transition(("success", "success", "cancelled", "success"), False, [], URL)
        self.assertEqual(end, ("open", None, (), f"Failing jobs: domain\nRun: {URL}\n"))

    def test_skipped_ui_holds_while_an_issue_is_open(self) -> None:
        end = red.transition(("success", "success", "success", "skipped"), False, [8], URL)
        self.assertEqual(end, ("hold",))

    def test_failure_beats_a_skip_and_names_only_the_failure(self) -> None:
        end = red.transition(("failure", "success", "success", "skipped"), False, [], URL)
        self.assertEqual(end, ("open", None, (), IDS_BODY))

    def test_force_red_names_the_failure_and_adds_the_drill_line(self) -> None:
        end = red.transition(("failure", "skipped", "skipped", "skipped"), True, [], URL)
        self.assertEqual(
            end,
            ("open", None, (), f"Failing jobs: ids\nRun: {URL}\nDrill: force_red\n"),
        )

    def test_force_with_four_successes_holds(self) -> None:
        self.assertEqual(red.transition(OK, True, [9, 4], URL), ("hold",))

    def test_other_titles_and_pull_requests_are_dropped(self) -> None:
        pages = "\n".join(
            [
                json.dumps(
                    [
                        {"number": 3, "title": "main is red"},
                        {"number": 8, "title": "main is green", "labels": [{"name": "main-red"}]},
                        {
                            "number": 2,
                            "title": "main is red",
                            "labels": [{"name": "main-red"}],
                            "pull_request": {"url": "x"},
                        },
                        {"number": 5, "title": "main is red", "labels": [{"name": "main-red"}]},
                        {"number": 6, "title": "main is red", "labels": ["main-red"]},
                    ]
                ),
                json.dumps([{"number": 11, "title": "Main is red", "labels": [{"name": "main-red"}]}]),
            ]
        )
        self.assertEqual(red.red_issue_numbers(pages), [5, 6])

    def test_absent_and_hold_write_nothing(self) -> None:
        board = Board()
        red.apply(("absent",), URL, board)
        red.apply(("hold",), URL, board)
        self.assertEqual(board.creates, [])
        self.assertEqual(board.edits, [])
        self.assertEqual(board.closes, [])

    def test_close_writes_the_green_comment_in_order(self) -> None:
        board = Board()
        red.apply(("close", (4, 9)), URL, board)
        self.assertEqual(board.creates, [])
        self.assertEqual(board.edits, [])
        self.assertEqual(board.closes, [(4, GREEN), (9, GREEN)])

    def test_second_apply_of_the_same_open_end_edits_and_does_not_create(self) -> None:
        end = red.transition(("failure", "success", "success", "success"), False, [4, 10], URL)
        board = Board()
        red.apply(end, URL, board)
        red.apply(end, URL, board)
        self.assertEqual(board.creates, [])
        self.assertEqual([number for number, _body in board.edits], [4, 4])
        self.assertEqual(board.closes, [(10, "Duplicate of #4."), (10, "Duplicate of #4.")])

    def test_create_then_list_keeps_the_lowest_number(self) -> None:
        end = red.transition(("failure", "success", "success", "success"), False, [], URL)
        board = Board(after_create=lambda created: [created, 7])
        red.apply(end, URL, board)
        self.assertEqual([number for number, _body in board.creates], [41])
        self.assertEqual(board.edits, [(7, IDS_BODY)])
        self.assertEqual(board.closes, [(41, "Duplicate of #7.")])

    def test_created_number_missing_from_the_next_list_is_still_closed(self) -> None:
        end = red.transition(("failure", "success", "success", "success"), False, [], URL)
        board = Board(after_create=lambda _created: [7])
        red.apply(end, URL, board)
        self.assertEqual(board.edits, [(7, IDS_BODY)])
        self.assertEqual(board.closes, [(41, "Duplicate of #7.")])


class BoardCallTest(unittest.TestCase):
    def test_list_asks_for_the_label(self) -> None:
        calls = []

        def fake(args):
            calls.append(list(args))
            return "[]"

        original = red._gh
        red._gh = fake
        try:
            self.assertEqual(red.GhBoard("acme/perimedi").list_open(), [])
        finally:
            red._gh = original
        self.assertEqual(
            calls,
            [["api", "--paginate", "repos/acme/perimedi/issues?state=open&labels=main-red&per_page=100"]],
        )

    def test_create_makes_the_label_then_the_issue(self) -> None:
        calls = []

        def fake(args):
            calls.append(list(args))
            stdout = ""
            if list(args)[:2] == ["issue", "create"]:
                stdout = "https://github.com/acme/perimedi/issues/12\n"
            return subprocess.CompletedProcess(args, 0, stdout, "")

        original = red._run_gh
        red._run_gh = fake
        try:
            number = red.GhBoard("acme/perimedi").create("Failing jobs: ids\n")
        finally:
            red._run_gh = original
        self.assertEqual(number, 12)
        self.assertEqual(
            calls[0],
            [
                "label",
                "create",
                "main-red",
                "--repo",
                "acme/perimedi",
                "--color",
                "B60205",
                "--description",
                "CI owns this issue",
                "--force",
            ],
        )
        self.assertEqual(calls[1][:2], ["issue", "create"])
        self.assertIn("--label", calls[1])
        label_at = calls[1].index("--label")
        self.assertEqual(calls[1][label_at + 1], "main-red")

    def test_label_create_failure_still_opens_the_issue(self) -> None:
        calls = []

        def fake(args):
            listed = list(args)
            calls.append(listed)
            if listed[:2] == ["label", "create"]:
                return subprocess.CompletedProcess(args, 1, "", "permission denied\n")
            if listed[:2] == ["api", "--silent"]:
                return subprocess.CompletedProcess(args, 1, "", "not found\n")
            if listed[:2] == ["issue", "create"]:
                return subprocess.CompletedProcess(
                    args, 0, "https://github.com/acme/perimedi/issues/12\n", ""
                )
            if listed[:2] == ["api", "--paginate"]:
                return subprocess.CompletedProcess(args, 0, "[]", "")
            raise AssertionError(listed)

        original = red._run_gh
        red._run_gh = fake
        stderr = io.StringIO()
        try:
            with contextlib.redirect_stderr(stderr):
                end = red.transition(("failure", "success", "success", "success"), False, [], URL)
                red.apply(end, URL, red.GhBoard("acme/perimedi"))
        finally:
            red._run_gh = original
        creates = [call for call in calls if call[:2] == ["issue", "create"]]
        self.assertEqual(len(creates), 1)
        self.assertNotIn("--label", creates[0])
        self.assertFalse(any(call[:2] == ["issue", "close"] for call in calls))
        self.assertIn("warning: gh label create main-red failed: permission denied", stderr.getvalue())

    def test_label_create_failure_keeps_the_label_when_it_exists(self) -> None:
        calls = []

        def fake(args):
            listed = list(args)
            calls.append(listed)
            if listed[:2] == ["label", "create"]:
                return subprocess.CompletedProcess(args, 1, "", "already exists\n")
            if listed[:2] == ["api", "--silent"]:
                return subprocess.CompletedProcess(args, 0, "", "")
            if listed[:2] == ["issue", "create"]:
                return subprocess.CompletedProcess(
                    args, 0, "https://github.com/acme/perimedi/issues/12\n", ""
                )
            raise AssertionError(listed)

        original = red._run_gh
        red._run_gh = fake
        stderr = io.StringIO()
        try:
            with contextlib.redirect_stderr(stderr):
                number = red.GhBoard("acme/perimedi").create("Failing jobs: ids\n")
        finally:
            red._run_gh = original
        self.assertEqual(number, 12)
        creates = [call for call in calls if call[:2] == ["issue", "create"]]
        self.assertEqual(creates[0][creates[0].index("--label") + 1], "main-red")
        self.assertIn("warning: gh label create main-red failed: already exists", stderr.getvalue())


class WorkflowTest(unittest.TestCase):
    def test_main_status_permissions_and_needs(self) -> None:
        text = Path(__file__).resolve().parents[2].joinpath(".github/workflows/ci.yml").read_text()
        block = _job(text, "main-status")
        permissions = re.search(r"\n    permissions:\n((?:      .+\n)+)", block)
        self.assertIsNotNone(permissions)
        assert permissions is not None
        self.assertEqual(permissions.group(1), "      issues: write\n")
        self.assertNotIn("actions/checkout", block)
        self.assertNotIn("contents:", block)
        needs = re.search(r"needs:\s*\[([^\]]+)\]", block)
        self.assertIsNotNone(needs)
        assert needs is not None
        self.assertEqual([part.strip() for part in needs.group(1).split(",")], ["ids", "openspec", "domain", "ui"])
        self.assertEqual(text.count("issues: write"), 1)
        self.assertIn("&& 'true' || 'false'", block)
        self.assertEqual(
            _jobs_with_exact_if(text, _FORCE_RED_GUARD),
            ["openspec", "domain", "ui"],
        )


_FORCE_RED_GUARD = (
    "if: github.event_name == 'pull_request' || "
    "(github.ref == 'refs/heads/main' && !(github.event_name == 'workflow_dispatch' && "
    "(github.event.inputs.force_red == true || github.event.inputs.force_red == 'true')))"
)


def _jobs_with_exact_if(text: str, guard: str) -> list[str]:
    jobs: list[str] = []
    current: str | None = None
    for line in text.splitlines():
        match = re.fullmatch(r"  ([A-Za-z0-9-]+):", line)
        if match:
            current = match.group(1)
            continue
        if line.strip() == guard:
            jobs.append(current or "")
    return jobs


def _job(text: str, name: str) -> str:
    marker = f"\n  {name}:\n"
    start = text.index(marker) + 1
    later = re.search(r"\n  [A-Za-z0-9-]+:\n", text[start:])
    end = len(text) if later is None else start + later.start()
    return text[start:end]


if __name__ == "__main__":
    unittest.main()
