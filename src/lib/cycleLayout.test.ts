import { describe, expect, it } from 'vitest'
import {
  CYCLE_LABEL_COL_MIN_SE,
  CYCLE_LABEL_COL_PX,
  CYCLE_DAY_MIN_PX,
  CYCLE_DOSE_META_STICKY_LEFT_PX,
  selectedDayPlotLeftPct,
  selectedDayPlotCenterPct,
  selectedDayPlotWidthPct,
  clampBadgeCenterPx,
  badgeCenterForSelectionVisibility,
  selectedDayBadgeStyle,
} from './cycleLayout'

describe('cycleLayout constants', () => {
  it('keeps sticky label column wide enough for SE med-name readability', () => {
    expect(CYCLE_LABEL_COL_PX).toBeGreaterThanOrEqual(CYCLE_LABEL_COL_MIN_SE)
  })

  it('uses compact day columns (half prior 44px touch min)', () => {
    expect(CYCLE_DAY_MIN_PX).toBe(22)
  })

  it('leaves room for day plot on 375px SE when labels are sticky', () => {
    const seWidth = 375
    const remaining = seWidth - CYCLE_LABEL_COL_PX
    // Compact columns: at least ~8 day columns of dayMin still fit beside labels
    expect(remaining).toBeGreaterThanOrEqual(CYCLE_DAY_MIN_PX * 8)
  })

  it('pins dose meta sticky left to the right of the med label column', () => {
    expect(CYCLE_DOSE_META_STICKY_LEFT_PX).toBeGreaterThan(CYCLE_LABEL_COL_PX)
  })
})

describe('selectedDay plot geometry (plot band only)', () => {
  it('places day 1 at the start of the plot', () => {
    expect(selectedDayPlotLeftPct(1, 28)).toBe(0)
    expect(selectedDayPlotCenterPct(1, 28)).toBeCloseTo(100 / 56, 5)
  })

  it('places mid-cycle day proportionally within the plot (not label column)', () => {
    expect(selectedDayPlotLeftPct(15, 28)).toBeCloseTo((14 / 28) * 100, 5)
    expect(selectedDayPlotWidthPct(28)).toBeCloseTo(100 / 28, 5)
  })

  it('clamps invalid days into range', () => {
    expect(selectedDayPlotLeftPct(0, 10)).toBe(0)
    expect(selectedDayPlotLeftPct(99, 10)).toBeCloseTo(90, 5)
  })
})

describe('clampBadgeCenterPx', () => {
  it('keeps badge fully inside the plot on the left edge', () => {
    // day center near 0, badge 120px, plot 220px → center at least 60+pad
    expect(clampBadgeCenterPx(5, 220, 120, 4)).toBe(64)
  })

  it('keeps badge fully inside the plot on the right edge', () => {
    expect(clampBadgeCenterPx(210, 220, 120, 4)).toBe(220 - 60 - 4)
  })

  it('leaves mid positions unchanged', () => {
    expect(clampBadgeCenterPx(110, 220, 100, 4)).toBe(110)
  })
})

describe('badgeCenterForSelectionVisibility', () => {
  const pad = 4
  const badgeW = 120
  // Visible plot slice in plot-local coords (e.g. scrolled so only 0–200 shows).
  const visLeft = 0
  const visRight = 200

  it('clamps when selection is still partially visible on the right', () => {
    // Day column near right edge of visible slice.
    const dayLeft = 170
    const dayRight = 210
    const dayCenter = 190
    const left = badgeCenterForSelectionVisibility({
      dayCenterPx: dayCenter,
      dayLeftPx: dayLeft,
      dayRightPx: dayRight,
      visLeftPx: visLeft,
      visRightPx: visRight,
      badgeWidthPx: badgeW,
      padPx: pad,
    })
    expect(left).toBe(200 - 60 - pad) // fully inside visible right
  })

  it('uses natural day center once selection has fully scrolled out right', () => {
    const dayLeft = 210
    const dayRight = 250
    const dayCenter = 230
    expect(
      badgeCenterForSelectionVisibility({
        dayCenterPx: dayCenter,
        dayLeftPx: dayLeft,
        dayRightPx: dayRight,
        visLeftPx: visLeft,
        visRightPx: visRight,
        badgeWidthPx: badgeW,
        padPx: pad,
      }),
    ).toBe(dayCenter)
  })

  it('uses natural day center once selection has fully scrolled out left', () => {
    const dayLeft = -40
    const dayRight = 0
    const dayCenter = -20
    expect(
      badgeCenterForSelectionVisibility({
        dayCenterPx: dayCenter,
        dayLeftPx: dayLeft,
        dayRightPx: dayRight,
        visLeftPx: visLeft,
        visRightPx: visRight,
        badgeWidthPx: badgeW,
        padPx: pad,
      }),
    ).toBe(dayCenter)
  })

  it('leaves mid-visible selection unclamped', () => {
    expect(
      badgeCenterForSelectionVisibility({
        dayCenterPx: 100,
        dayLeftPx: 80,
        dayRightPx: 120,
        visLeftPx: visLeft,
        visRightPx: visRight,
        badgeWidthPx: badgeW,
        padPx: pad,
      }),
    ).toBe(100)
  })
})

describe('selectedDayBadgeStyle', () => {
  it('shifts first-day badge right so half-width stays in plot', () => {
    const s = selectedDayBadgeStyle(1, 28, 0.4)
    expect(s.leftPct).toBeGreaterThan(0)
    expect(s.transform).toBe('translateX(-50%)')
  })

  it('shifts last-day badge left so half-width stays in plot', () => {
    const s = selectedDayBadgeStyle(28, 28, 0.4)
    expect(s.leftPct).toBeLessThan(100)
    expect(s.leftPct).toBeCloseTo(80, 5) // 100 - 20
  })

  it('centers mid-cycle when there is room', () => {
    const s = selectedDayBadgeStyle(14, 28, 0.3)
    expect(s.leftPct).toBeCloseTo(selectedDayPlotCenterPct(14, 28), 5)
  })
})
