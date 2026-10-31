---
name: check-symptom-sync
description: "Check custom-symptom sync when a change touches SymptomDirectory.synced, Store.refresh, Store.apply, Store.replaceAll, clearAll, wipeDomain, or perimedi.rememberedScoreRewrites. Run the model, and use /maintain-formal-verification-skill when a merge skipped this skill."
---

# Check custom-symptom sync

`SymptomDirectory.synced` deletes iCloud-synced scores when two phones fold the same custom name. Example tests cover the cases someone wrote down. This model checks every interleaving inside its bounds.

## When

Run `python3 ios/scripts/check-symptom-sync.py` before you finish an edit to the covered code. A change to `SymptomDirectory.synced` is the trigger, including a change to `fold`, `merging`, or `map`.

If the edit changes what `synced` promises, update `ios/formal/symptom-sync/SymptomSync.tla` in the same change. Move the sync commit only after the model describes the new code. A docs-only edit does not move it.

`python3 ios/scripts/check-symptom-model.py` fails the `ids` job when a covered symbol changes, or a covered file is renamed or deleted, and that same change leaves `SymptomSync.tla`, `SymptomSync.cfg`, and the sync commit below untouched.

When a merge changed the covered code and skipped this skill, use `/maintain-formal-verification-skill`.

## Command

From the repo root:

```bash
python3 ios/scripts/check-symptom-sync.py
```

The command exits 1 when an invariant fails. CI runs the same command with `--warn` and does not fail the workflow. Do not add the command to `control-perimedi verify`.

The checker downloads TLC 1.7.4 on first use and needs `java` on PATH (Java 11 or later).

## What a result means

`PASS` means that invariant holds for every interleaving in the model. `FAIL` on `EmptyKeeperSafe` is issue #120. `FAIL` on `ImportRemembers` is issue #121. Any other `FAIL` is a new bug, or the model no longer describes the code.

Do not weaken an invariant to make the command pass. Do not change product code from this skill unless the user asks. Read the TLC output with the pstack `/statechart` skill. It shows each broken rule as its shortest path.

The model is past the chart budget. While every rule holds, `/statechart` writes no diagram. The note is `docs/statecharts/symptom-sync.md`.

## Covered code

- `SymptomDirectory.synced` (both overloads), `fold`, `merging`, and `map` in `ios/Sources/PeriMediDomain/SymptomDirectory.swift`
- `Store.refresh`, `Store.apply`, `Store.replaceAll`, `Store.clearAll`, `Store.wipeDomain`, and `SymptomFoldDefaults` in `ios/PeriMedi/Persistence/Store.swift`
- `SDSymptomScore.recordId` in `ios/PeriMedi/Persistence/SwiftDataModels.swift`

Sync commit: `7b8c3af`

## Bounds

Two ids, `a` and `b`. `a` is the earlier sort and the lower id. Two names, fog and ache. Two days. One remembered pair, `b` removed onto `a`. A record id is the unique `date#id`, or the empty default.

The phone's main actor runs one refresh at a time. The model does not include a CloudKit write inside `apply`. After `SymptomFoldDefaults.saveSnapshot` or `SymptomFoldDefaults.mergeFresh` returns, the key is durable.

## Left out

Left out: chain flattening in remembering() and terminal().

`prefer`'s tie-break. Case folding where ß and ss differ. CloudKit's transport and merge policy. A `UserDefaults` flush versus the SQLite commit. Blank-name rows. A malformed defaults blob.

## Findings

`EmptyKeeperSafe` holds. When two stored rows share an empty record id, the next refresh stamps both to `date#id`. The earlier day stays. A lone empty id stays empty. Filed as #120.

`ImportRemembers` holds. Import folds two same names and saves the store. It then merges that fresh pair onto the key already on this phone. A later score for a removed id shows on the symptom that remains. Filed as #121.

`ScoreOnListedSymptom` holds. A pair saved before a failed store save does not hide a mark whose symptom is still listed, once the next save lands. The failure snapshot can hide a late score until that next save.

`OrphanStaysOut` holds. A mark the file left out is not inserted, so the key that wipe and import leave in place does not bring that row back. A later score for a pair this phone already stored still uses that key. That is the late-score rule.
