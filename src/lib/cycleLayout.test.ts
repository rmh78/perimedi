import { describe, expect, it } from 'vitest'
import {
  CYCLE_LABEL_COL_MIN_SE,
  CYCLE_LABEL_COL_PX,
  CYCLE_DAY_MIN_PX,
  CYCLE_DOSE_META_STICKY_LEFT_PX,
  selectedDayPlotLeftPct,
  selectedDayPlotCenterPct,
  selectedDayPlotWidthPct,
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
