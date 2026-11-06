---
name: peridesign
description: Use when changing a SwiftUI view, screen, dialog, sheet, colour, font, or padding, or when the user runs /peridesign. Apply PeriDesign tokens and run the design lint.
---

# PeriDesign

Tokens live in `ios/Packages/PeriDesign/Sources/PeriDesign/Tokens/`.

| Type | Members |
|---|---|
| PeriColor | blush25, blush50, blush100, blush200, blush300, blush400, blush500, blush600, blush700, blush800, lilac50, cream, ink, inkSoft, inkMuted, taken, pending, symptom, pageWash, pageWashLilac, pillGradientEnd, launchPeach |
| PeriSpace | row, pad, minControl, hairline |
| PeriRadius | card |
| PeriFont | pillLabel, brand |

Use `PeriColor`, `PeriSpace`, `PeriRadius`, `PeriFont`. Never a hex string, `Color(red:)`, a literal font size, or a magic padding number.

Prefer an existing PeriDesign component before ad hoc UI: `PeriButtonStyle(role:)`, `DialogActions`, `.periDialog`, pill, badge, empty state, section header, form row. Those types are not in the package yet. Do not build them in the app. A new primitive goes in the package with a preview.

Dialog footer order: Cancel on the left, optional destructive in the middle, one primary on the right. Every dialog has Cancel.

Run `python3 ios/scripts/check-design-system.py --base origin/main`. Never add a baseline line. If you remove a violation in a file you touch, lower or delete that baseline row.

Proof is `.grok/skills/verify-perimedi/scripts/control-perimedi verify`, English and German. Large text is at most two steps above Large (`UICTContentSizeCategoryXL` or `UICTContentSizeCategoryXXL`, issue #117). Never an `Accessibility*` size. Leave visual taste to poteto-mode.
