import { describe, expect, it } from 'vitest'
import { dayOfMonth, daysInMonth, startOfMonthKey } from './dates'

describe('dayOfMonth', () => {
  it('returns the calendar day of month', () => {
    expect(dayOfMonth('2026-03-15')).toBe(15)
    expect(dayOfMonth('2026-03-01')).toBe(1)
    expect(dayOfMonth('2026-08-31')).toBe(31)
  })

  it('returns the first of the month and the month length', () => {
    expect(startOfMonthKey('2026-08-19')).toBe('2026-08-01')
    expect(daysInMonth('2026-08-19')).toBe(31)
    expect(daysInMonth('2026-02-10')).toBe(28)
  })
})
