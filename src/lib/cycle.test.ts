import { describe, expect, it } from 'vitest'
import type { CycleSettings, Period } from '../types'
import {
  cycleWindowForDate,
  getCycleDay,
  getDayCycleInfo,
  nextPredictedPeriodStart,
  periodLengthDays,
} from './cycle'

const settings: CycleSettings = {
  id: 'default',
  averageCycleLength: 28,
  averagePeriodLength: 5,
}

describe('cycleWindowForDate', () => {
  it('starts at the selected date when no periods exist', () => {
    const w = cycleWindowForDate('2026-08-07', [], settings)
    expect(w.start).toBe('2026-08-07')
    expect(w.length).toBeGreaterThanOrEqual(28)
  })

  it('uses the period start on or before the date', () => {
    const periods: Period[] = [{ id: 'p1', startDate: '2026-07-10' }]
    const w = cycleWindowForDate('2026-07-20', periods, settings)
    expect(w.start).toBe('2026-07-10')
    expect(w.length).toBe(28)
  })

  it('extends the window so a late selected day stays visible', () => {
    const periods: Period[] = [{ id: 'p1', startDate: '2026-06-01' }]
    const w = cycleWindowForDate('2026-07-20', periods, settings)
    expect(w.start).toBe('2026-06-01')
    expect(w.length).toBeGreaterThan(28)
    expect(w.length).toBeLessThanOrEqual(90)
  })
})

describe('getCycleDay / getDayCycleInfo', () => {
  const periods: Period[] = [
    { id: 'p1', startDate: '2026-07-10', endDate: '2026-07-14' },
  ]

  it('returns cycle day 1 on the period start', () => {
    expect(getCycleDay('2026-07-10', periods)).toBe(1)
  })

  it('marks logged period days and not predicted', () => {
    const info = getDayCycleInfo('2026-07-12', periods, settings)
    expect(info.isLoggedPeriod).toBe(true)
    expect(info.isPredictedPeriod).toBe(false)
    expect(info.cycleDay).toBe(3)
  })

  it('predicts the next period from the last start + cycle length', () => {
    const next = nextPredictedPeriodStart(periods, settings)
    expect(next).toBe('2026-08-07')
    const info = getDayCycleInfo('2026-08-07', periods, settings)
    expect(info.isPredictedPeriod).toBe(true)
    expect(info.isLoggedPeriod).toBe(false)
  })
})

describe('periodLengthDays', () => {
  it('uses inclusive start/end when both exist', () => {
    expect(
      periodLengthDays(
        { id: 'p', startDate: '2026-07-10', endDate: '2026-07-14' },
        5,
      ),
    ).toBe(5)
  })

  it('falls back to default when open-ended', () => {
    expect(periodLengthDays({ id: 'p', startDate: '2026-07-10' }, 6)).toBe(6)
  })
})
