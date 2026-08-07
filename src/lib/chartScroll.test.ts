import { describe, expect, it } from 'vitest'
import { computeDayScrollLeft } from './chartScroll'

const LABEL = 120
const DAY_MIN = 44

describe('computeDayScrollLeft', () => {
  it('returns null when content is not expanded but chart should overflow (Firefox first paint)', () => {
    const cycleLen = 28
    const chartMinWidth = LABEL + cycleLen * DAY_MIN
    const result = computeDayScrollLeft({
      cycleDay: 15,
      cycleLen,
      labelColPx: LABEL,
      dayMinPx: DAY_MIN,
      clientWidth: 375,
      contentWidth: 375, // not ready
      chartMinWidth,
    })
    expect(result).toBeNull()
  })

  it('centers a mid-cycle day in the visible plot band (not full viewport)', () => {
    const cycleLen = 28
    const chartMinWidth = LABEL + cycleLen * DAY_MIN // 1352
    const clientWidth = 375
    const mid = 15
    const result = computeDayScrollLeft({
      cycleDay: mid,
      cycleLen,
      labelColPx: LABEL,
      dayMinPx: DAY_MIN,
      clientWidth,
      contentWidth: chartMinWidth,
      chartMinWidth,
    })
    expect(result).not.toBeNull()

    // Day center in content coords
    const plotWidth = chartMinWidth - LABEL
    const colW = plotWidth / cycleLen
    const dayCenterX = LABEL + (mid - 0.5) * colW
    const visiblePlotCenterX = LABEL + (clientWidth - LABEL) / 2
    const expected = dayCenterX - visiblePlotCenterX
    expect(result).toBeCloseTo(expected, 5)

    // Must scroll past 0 for mid-cycle on SE width
    expect(result!).toBeGreaterThan(100)
  })

  it('clamps to 0 for early cycle days when already left-aligned', () => {
    const cycleLen = 28
    const chartMinWidth = LABEL + cycleLen * DAY_MIN
    const result = computeDayScrollLeft({
      cycleDay: 1,
      cycleLen,
      labelColPx: LABEL,
      dayMinPx: DAY_MIN,
      clientWidth: 375,
      contentWidth: chartMinWidth,
      chartMinWidth,
    })
    expect(result).toBe(0)
  })

  it('returns 0 when chart fits without overflow', () => {
    const cycleLen = 5
    const chartMinWidth = LABEL + cycleLen * DAY_MIN
    const result = computeDayScrollLeft({
      cycleDay: 3,
      cycleLen,
      labelColPx: LABEL,
      dayMinPx: DAY_MIN,
      clientWidth: 900,
      contentWidth: chartMinWidth,
      chartMinWidth,
    })
    expect(result).toBe(0)
  })
})
