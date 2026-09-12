# Screen catalog

Main-screen Simulator PNGs live in `screens/`. `ScreenCatalogTests` writes them locally by navigating a few sessions (empty, sample, Trends fixture, no-scores), including German via More language pills — not one app launch per file. Commit the PNGs. UX reviews the **image diff in Files changed**. CI does not rewrite them; it only fails if a committed file is missing. Skip the writer locally with `SCREEN_CATALOG=0`.

Do **not** paste screenshot galleries into PR comments. Do **not** use a per-PR dump (`pr-41-simulator` or any pull-request id in the path).

English, plus German when chrome changes: Cycle empty, Cycle with data, Trends empty, Trends with data, Trends Choose Symptoms sheet, Trends dot tap, Trends dose-tick sentence, Trends no-scores, Month, More, visit cycle picker, in-app visit PDF preview, add-medication sheet, period sheet, symptom sheet. Names are `{screen}-{state}-{locale}.png` (see `screens/expected.txt`). Do not keep old chip-cloud layout shots.

CI fails only if an expected file is **missing**. Pixel drift does not fail the suite. After a layout change, run `bash ios/scripts/verify.sh` and commit any updated PNGs.
