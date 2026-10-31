# Custom symptom sync

TLC reached 77,328 states, more than the chart budget of 500, and every checked rule holds, so the tool wrote no chart.

TLC found none.

The model leaves out chain flattening in `remembering()` and `terminal()`, `prefer`'s tie-break, and case folding where ß and ss differ. It leaves out CloudKit's transport and merge policy, a `UserDefaults` flush versus the SQLite commit, blank-name rows, and a malformed defaults blob.

Regenerate with `/statechart` on `ios/formal/symptom-sync/SymptomSync.tla`, using `ios/formal/symptom-sync/SymptomSync.cfg` and `ios/formal/symptom-sync/view.mjs`, into an empty directory. `ios/scripts/check-statecharts.py` checks that the tool still writes no fence.
