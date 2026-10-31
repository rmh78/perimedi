# Custom symptom sync

This picture uses one day, the name fog, and logs a mark only on the first symptom, so the sync fits on one page. The full check uses two days, the names fog and ache, and logs a mark on either symptom. The picture keeps both symptom ids, because the start state names the second one.

![Custom symptom sync](symptom-sync.svg)

## What TLC checked

TLC reached 77328 states on the full check and reported no error. This picture reached 254 states.

LateScoreKept holds. A later mark for a removed copy shows on the symptom that remains.

NeverCombinedHides holds. This phone never combined the pair, so the late mark stays hidden.

WinnerGoneHides holds. The kept symptom is gone, so the mark stays hidden.

UniqueMarkRemains holds. A saved mark stays on its own symptom or on the symptom this phone kept. Deleting it removes it.

EmptyKeeperSafe holds. An empty record id used as the keeper does not remove a mark on another day.

ImportRemembers holds. A backup that combined two names stores the pair.

ScoreOnListedSymptom holds. A score stays on screen while its symptom is still listed.

OrphanStaysOut holds. A mark the file left out stays off the list.

NoDeadlock holds.

The model leaves out chain flattening in `remembering()` and `terminal()`, `prefer`'s tie-break, and case folding where ß and ss differ. It leaves out CloudKit's transport and merge policy, a UserDefaults flush versus the SQLite commit, blank-name rows, and a malformed defaults blob.

`python3 ios/scripts/check-statecharts.py` checks this fence and this picture.

```mermaid
---
title: "Custom symptom sync on one phone"
---
stateDiagram-v2
  state "Legend" as legend {
    lg0: Lost
    lg1: Saving
    lg2: Settled
  }
  class lg0 pink
  class lg1 yellow
  class lg2 teal
  s0: No custom symptoms
  s1: One custom symptom
  s2: One symptom remains, and the pair is remembered
  s3: The pairs are saved and the store save is still open
  s4: The save failed and the list rolled back
  s5: Two phones added the same name
  s6: A saved day is gone
  [*] --> s0
  s0 --> s1: you add a symptom or the other phone adds a symptom or you import a backup that left a mark out
  s0 --> s2: you import a backup that joined two names or you import a backup that left a mark out or you add a symptom or the other phone adds a symptom
  s0 --> s3: the phone saves the remembered pairs
  s1 --> s0: you clear this phone or you delete it
  s1 --> s2: you import a backup that joined two names or you import a backup that left a mark out
  s1 --> s5: the other phone adds a symptom
  s1 --> s3: the phone saves the remembered pairs
  s2 --> s0: you delete it or you clear this phone
  s2 --> s5: the other phone adds a symptom
  s2 --> s3: the phone saves the remembered pairs
  s3 --> s0: the store save lands
  s3 --> s4: the store save fails
  s4 --> s0: you clear this phone or the store save lands
  s4 --> s1: you import a backup that left a mark out or the store save lands
  s4 --> s2: you import a backup that joined two names or you import a backup that left a mark out or the store save lands
  s5 --> s0: you clear this phone
  s5 --> s1: you delete it or you import a backup that left a mark out
  s5 --> s2: you import a backup that joined two names or you import a backup that left a mark out or you delete it
  s5 --> s3: the phone saves the remembered pairs
  s3 --> s1: the store save lands
  s3 --> s6: the store save lands
  s3 --> s2: the store save lands
  s6 --> s0: you clear this phone or you delete it
  s6 --> s1: you import a backup that left a mark out or you add a symptom or the other phone adds a symptom or you rename it
  s6 --> s2: you import a backup that joined two names or you import a backup that left a mark out or you add a symptom or the other phone adds a symptom
  s6 --> s5: the other phone adds a symptom
  s4 --> s6: the store save lands
  s6 --> s4: the store save fails
  class s0 teal
  class s1 teal
  class s2 teal
  class s3 yellow
  class s4 yellow
  class s5 teal
  class s6 pink
  classDef happy fill:#ffcbe6,stroke:#c45c8a
  classDef bugPath stroke:#e72e3b,stroke-width:2.5px
```
