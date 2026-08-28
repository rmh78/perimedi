# Agent gotchas

Line budget: 40 (this file, all lines). CI fails over that.
Surprises only. Do not restate AGENTS.md. Add a hit, drop a stale line.

- Simulator Connect Hardware Keyboard eats `typeText` (FB9148288). The doctor turns it off before boot. Truncation is a red fail. Do not paste.
- GitHub file-write of large Swift (especially `CycleView.swift`, about 769 lines / 33KB) can truncate. Never replace it unless the written file is complete.
- No Cursor Cloud Agents on this plan. Do not clone. Repo work is GitHub PRs.
- UI tests stay on the user keyboard path: tap, wait for the software keyboard, `typeText` once, assert the exact value.
