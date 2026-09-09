# Screen catalog

Main-screen Simulator PNGs live in `screens/`. UI tests write them (`ScreenCatalogTests`). Commit the PNGs. UX reviews the **image diff in Files changed**.

Do **not** paste screenshot galleries into PR comments. Do **not** use a per-PR dump (`pr-41-simulator` or any pull-request id in the path).

English, plus German when chrome changes: Cycle empty, Cycle with data, Trends empty, Trends with data, Month, More. Names are `{screen}-{state}-{locale}.png` (see `screens/expected.txt`).

CI fails only if an expected file is **missing**. Pixel drift does not fail the suite. After a layout change, run `bash ios/scripts/verify.sh` and commit any updated PNGs.
