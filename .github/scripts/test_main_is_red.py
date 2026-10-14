#!/usr/bin/env python3
from __future__ import annotations

import json
import re
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
                        {"number": 8, "title": "main is green"},
                        {"number": 2, "title": "main is red", "pull_request": {"url": "x"}},
                    ]
                ),
                json.dumps([{"number": 11, "title": "Main is red"}]),
            ]
        )
        self.assertEqual(red.red_issue_numbers(pages), [3])

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
        drill_if = [
            line.strip()
            for line in text.splitlines()
            if line.strip().startswith("if: github.event_name == 'pull_request' || (github.ref")
        ]
        self.assertEqual(drill_if, [drill_if[0], drill_if[0], drill_if[0]])


def _job(text: str, name: str) -> str:
    marker = f"\n  {name}:\n"
    start = text.index(marker) + 1
    later = re.search(r"\n  [A-Za-z0-9-]+:\n", text[start:])
    end = len(text) if later is None else start + later.start()
    return text[start:end]


if __name__ == "__main__":
    unittest.main()
