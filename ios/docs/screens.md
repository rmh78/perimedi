# Screen catalog

Main-screen Simulator PNGs live in `screens/`. `expected.txt` lists sixteen English catalog names, `sheet-symptom-pill-de.png`, and the two widget pictures. `ScreenCatalogTests` writes the sixteen English names by navigating a few sessions (empty, sample, Trends fixture, no-scores), not one app launch per file. It switches to German only to write `sheet-symptom-pill-de.png`. The widget journey rewrites `widget-medium-before-en.png` and `widget-medium-after-en.png` on every run, including `drive` and GitHub. Commit the PNGs. UX reviews the **image diff in Files changed**. CI does not rewrite the catalog pictures. It only fails if a committed file is missing. Skip the catalog writer locally with `SCREEN_CATALOG=0`.

Do **not** paste screenshot galleries into PR comments. Do **not** use a per-PR dump (`pr-41-simulator` or any pull-request id in the path).

English catalog pictures: Cycle empty, Cycle with data, Trends empty, Trends with data, Trends Choose Symptoms sheet, Trends dot tap, Trends dose-tick sentence, Trends no-scores, Month, More, visit cycle picker, in-app visit PDF preview, add-medication sheet, period sheet, symptom sheet, and the symptom sheet with a wrapped custom name. The one German catalog picture is the New symptom pill (`sheet-symptom-pill-de.png`). The widget pictures are the medium card before and after Take. Names are `{screen}-{state}-{locale}.png` (see `screens/expected.txt`). Do not keep old chip-cloud layout shots.

CI fails only if an expected file is **missing**. Pixel drift does not fail the suite. After a layout change, run `.grok/skills/verify-perimedi/scripts/control-perimedi verify` and commit any updated PNGs.
