import { describe, expect, it } from 'vitest'
import type { CycleSettings, Period } from '../types'
import { doseExpansionRange } from './doseRange'

const settings: CycleSettings = {
  id: 'default',
  averageCycleLength: 28,
  averagePeriodLength: 5,
  tracksPeriods: true,
}

describe('doseExpansionRange', () => {
  it('covers today and selected date when there are no periods', () => {
    const r = doseExpansionRange({
      today: '2026-08-07',
      selectedDate: '2026-08-01',
      periods: [],
      settings,
    })
    expect(r.from).toBe('2026-08-01')
    expect(r.to >= '2026-08-07').toBe(true)
  })

  it('includes the latest logged cycle start', () => {
    const periods: Period[] = [{ id: 'p1', startDate: '2026-07-10' }]
    const r = doseExpansionRange({
      today: '2026-08-07',
      selectedDate: '2026-08-07',
      periods,
      settings,
    })
    expect(r.from).toBe('2026-07-10')
  })

  it('widens with extra month grid bounds', () => {
    const r = doseExpansionRange({
      today: '2026-08-07',
      selectedDate: '2026-08-07',
      periods: [],
      settings,
      extraFrom: ['2026-07-01'],
      extraTo: ['2026-09-05'],
    })
    expect(r.from).toBe('2026-07-01')
    expect(r.to).toBe('2026-09-05')
  })
})
