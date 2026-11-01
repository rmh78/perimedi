# Screen catalog

Main-screen Simulator PNGs live in `screens/`. `expected.txt` lists seventeen English catalog names, including the largest-text More picture `more-sample-xxxl-en.png`, plus the German pictures `sheet-symptom-pill-de.png` and `more-sample-de.png`, and the two widget pictures. `ScreenCatalogTests` writes those English names by navigating a few sessions (empty, sample, Trends fixture, no-scores, and one largest-text More launch), not one app launch per file. It switches to German to write `sheet-symptom-pill-de.png` and `more-sample-de.png`. The widget journey rewrites `widget-medium-before-en.png` and `widget-medium-after-en.png` on every full run, including `drive` and the nightly GitHub run. The pull-request smoke does not rewrite the catalog or those widget pictures. Commit the PNGs. UX reviews the **image diff in Files changed**. The full suite rewrites the catalog unless `SCREEN_CATALOG=0`. The `ids` job still fails if a committed file is missing.

`ios/docs/copy-review/` holds one-off #44 German before/after copy shots, is not in `expected.txt`, is not checked by `check-screen-catalog.py`, and may be deleted after merge.

Do **not** paste screenshot galleries into PR comments. Do **not** use a per-PR dump (`pr-41-simulator` or any pull-request id in the path).

English catalog pictures: Cycle empty, Cycle with data, Trends empty, Trends with data, Trends Choose Symptoms sheet, Trends dot tap, Trends dose-tick sentence, Trends no-scores, Month, More, More at the largest text size, visit cycle picker, in-app visit PDF preview, add-medication sheet, period sheet, symptom sheet, and the symptom sheet with a wrapped custom name. The German catalog pictures are the New symptom pill (`sheet-symptom-pill-de.png`) and More (`more-sample-de.png`). The widget pictures are the medium card before and after Take. Names are `{screen}-{state}-{locale}.png` (see `screens/expected.txt`). Do not keep old chip-cloud layout shots.

CI fails only if an expected file is **missing**. Pixel drift does not fail the suite. After a layout change, run `.grok/skills/verify-perimedi/scripts/control-perimedi verify` and commit any updated PNGs.
