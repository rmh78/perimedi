---
name: check-symptom-sync
description: "Check custom-symptom sync when a change touches SymptomDirectory.synced, Store.refresh, Store.apply, Store.replaceAll, clearAll, wipeDomain, or perimedi.rememberedScoreRewrites. Run the model, and use /maintain-formal-verification-skill when a merge skipped this skill."
---

# Check custom-symptom sync

`SymptomDirectory.synced` deletes iCloud-synced scores when two phones fold the same custom name. Example tests cover the cases someone wrote down. This model checks every interleaving inside its bounds.

## When

Run `python3 ios/scripts/check-symptom-sync.py` before you finish an edit to the covered code. A change to `SymptomDirectory.synced` is the trigger, including a change to `fold`, `merging`, `map`, or `RememberedScoreRewrites.remembering`.

If the edit changes what `synced` promises, update `ios/formal/symptom-sync/SymptomSync.tla` in the same change. Move the sync commit only after the model describes the new code. A docs-only edit does not move it.

`python3 ios/scripts/check-symptom-model.py` fails the `ids` job when a covered Swift file changes and that same change leaves `SymptomSync.tla`, `SymptomSync.cfg`, and the sync commit below untouched.

When a merge changed the covered code and skipped this skill, use `/maintain-formal-verification-skill`.

## Command

From the repo root:

```bash
python3 ios/scripts/check-symptom-sync.py
```

The command exits 1 while `EmptyKeeperSafe` or `ImportRemembers` fails. CI runs the same command with `--warn` and does not fail the workflow. Do not add the command to `control-perimedi verify`.

The checker downloads TLC 1.7.4 on first use and needs `java` on PATH (Java 11 or later).

## What a result means

`PASS` means that invariant holds for every interleaving in the model. `FAIL` on `EmptyKeeperSafe` is issue #120. `FAIL` on `ImportRemembers` is issue #121. Any other `FAIL` is a new bug, or the model no longer describes the code.

Do not weaken an invariant to make the command pass. Do not change product code from this skill unless the user asks. Read the TLC output with the pstack `/statechart` skill. It shows each broken rule as its shortest path.

The committed chart at `ios/formal/symptom-sync/chart.mmd` draws those two broken paths. The model is larger than a full chart, so the picture leaves out the other steps.

## Covered code

- `SymptomDirectory.synced` (both overloads), `fold`, `merging`, `map`, and `RememberedScoreRewrites.remembering` in `ios/Sources/PeriMediDomain/SymptomDirectory.swift`
- `Store.refresh`, `Store.apply`, `Store.replaceAll`, `Store.clearAll`, `Store.wipeDomain`, and `SymptomFoldDefaults` in `ios/PeriMedi/Persistence/Store.swift`
- `SDSymptomScore.recordId` in `ios/PeriMedi/Persistence/SwiftDataModels.swift`

Sync commit: `dd69ec0`

## Bounds

Two ids, `a` and `b`. `a` is the earlier sort and the lower id. Two names, fog and ache. Two days. One remembered pair, `b` removed onto `a`. A record id is the unique `date#id`, or the empty default.

The phone's main actor runs one refresh at a time. The model does not include a CloudKit write inside `apply`. After `SymptomFoldDefaults.save` returns, the key is durable.

## Left out

`prefer`'s tie-break. Chains of three or more hops. Case folding where ß and ss differ. CloudKit's transport and merge policy. A `UserDefaults` flush versus the SQLite commit. Blank-name rows. A malformed defaults blob.

## Findings

`EmptyKeeperSafe` fails. Two days share the empty record id. The first store save can still show both days. The next refresh drops the earlier day. Writers today set `date#id` before insert. The empty id is the Swift default on `SDSymptomScore`. Filed as #120.

`ImportRemembers` fails. Import folds two same names and discards `plan.memory`. A later score for the removed id stays hidden. Filed as #121.

`ScoreOnListedSymptom` holds. A pair saved before a failed store save does not hide a mark whose symptom is still listed, once the next save lands. The failure snapshot can hide a late score until that next save.

`OrphanStaysOut` holds. A mark the file left out is not inserted, so the key that wipe and import leave in place does not bring that row back. A later score for a pair this phone already stored still uses that key. That is the late-score rule.
