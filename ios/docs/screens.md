# Screen catalog

Main-screen Simulator PNGs live in `screens/`. UI tests write them (`ScreenCatalogTests`). Commit the PNGs. UX reviews the **image diff in Files changed**.

Do **not** paste screenshot galleries into PR comments. Do **not** use a per-PR dump (`pr-41-simulator` or any pull-request id in the path).

English, plus German when chrome changes: Cycle empty, Cycle with data, Trends empty, Trends with data, Trends Change sheet, Trends dot tap, Trends dose-tick sentence, Trends no-scores, Month, More, visit cycle picker, in-app visit PDF preview. Names are `{screen}-{state}-{locale}.png` (see `screens/expected.txt`). Do not keep old chip-cloud layout shots.

CI fails only if an expected file is **missing**. Pixel drift does not fail the suite. After a layout change, run `bash ios/scripts/verify.sh` and commit any updated PNGs.
