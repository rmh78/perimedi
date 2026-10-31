# Review findings

Repeated review findings from merged pull requests. `AGENTS.md` links here. A guard of `not yet` has no failing check. This file is not input to a script.

| Finding | Pull requests | Guard |
| --- | --- | --- |
| A new UI test method is not named in Agents.md or a feature file. | #66, #105 | [`check-ui-test-names.py`](../scripts/check-ui-test-names.py) from #105. #106 still asks for an exact name match and the error text `AGENTS.md`. |
| Markdown or the pull request body links a GitHub user-upload host. | #66, #105 | [`check-pr-attachments.py`](../scripts/check-pr-attachments.py) from #105. |
| A python3 script under ios/scripts or .github/scripts runs in CI and Agents.md omits the file name. | #105, #107 | [`check-agent-rails.py`](../scripts/check-agent-rails.py) from #105. It does not see docs/app-store. #107 added the listing command to Agents.md by hand. |
| Pull request screenshots show an older commit, or a behavior change leaves the body stale. | #66, #105, #114 | Tracked in #106. Not rebuilt. |
| An ios/docs folder is missing from Agents.md. | #105, #106 | Tracked in #106. Not rebuilt. |
| The UI test name match is a substring, and the error says Agents.md. | #106 | Tracked in #106. Not rebuilt. |
| A date, a unit, or a decimal is a view-local literal, a language-code branch, or a dot swapped for a comma. | #66, #100, #102, #107 | [`check-review-repeats.py`](../scripts/check-review-repeats.py) on added Swift lines. The German placeholder ternary already in DialogChrome.swift stays until that line changes. |
| A number and the next month or unit can wrap because the space breaks. | #100, #114 | Date runs are pinned by DateCopyTests (`4.` plus U+00A0 plus `April`, and `Mar` plus U+00A0 plus `7`). New `minutes` or `Minuten` lines in L10n.swift fail in [`check-review-repeats.py`](../scripts/check-review-repeats.py). The reminder sentences already on main stay until those lines change. |
| A label names the control and omits the object or the outcome. | #66, #114 | not yet |
| A new control uses a second pattern beside the sibling control. | #66, #114 | not yet |
| A green check never sees the new case. Examples are catalogOnly fixtures, a listing check that ignores PNG size, and one accessibility id covering a whole sheet. | #66, #108, #114 | not yet. Extra catalog PNGs and per-change screenshot folders stay in #106. |
| A spec or a feature note still describes the old control. | #66, #102 | not yet. #105 does not check the sentence next to a file name, because that check fails the manual build example in Agents.md. |
| A simulator failure outside the diff costs another review round. | #66, #114 | not yet |
| A covered symbol in the symptom-sync skill changes and the TLA model stays on the old commit. | #77, #88, #90 | [`check-symptom-model.py`](../scripts/check-symptom-model.py). The symbols and the sync commit live in `.grok/skills/check-symptom-sync/SKILL.md`. A rename uses `git diff --no-renames`. |
| A new job copies the force_red guard and the drill test only counts copies. | #122 | `test_main_status_permissions_and_needs` names `openspec`, `domain`, `ui`, `symptom-sync`, `dose-reminder`, and `statecharts`. |
