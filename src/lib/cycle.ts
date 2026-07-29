import { addDays, differenceInCalendarDays, parseISO } from 'date-fns'
import type { CycleSettings, DayCycleInfo, Period } from '../types'
import { toDateKey } from './dates'

function periodCoversDate(
  period: Period,
  dateKey: string,
  defaultPeriodLength: number,
): boolean {
  const start = toDateKey(period.startDate)
  if (dateKey < start) return false
  if (period.endDate) {
    return dateKey <= toDateKey(period.endDate)
  }
  const end = toDateKey(addDays(parseISO(start), defaultPeriodLength - 1))
  return dateKey <= end
}

export function sortPeriods(periods: Period[]): Period[] {
  return [...periods].sort((a, b) => b.startDate.localeCompare(a.startDate))
}

export function lastPeriodStart(periods: Period[]): string | null {
  const sorted = sortPeriods(periods)
  return sorted[0] ? toDateKey(sorted[0].startDate) : null
}

export function getCycleDay(dateKey: string, periods: Period[]): number | null {
  const starts = periods
    .map((p) => toDateKey(p.startDate))
    .filter((s) => s <= dateKey)
    .sort((a, b) => b.localeCompare(a))
  const last = starts[0]
  if (!last) return null
  return differenceInCalendarDays(parseISO(dateKey), parseISO(last)) + 1
}

export function getDayCycleInfo(
  dateKey: string,
  periods: Period[],
  settings: CycleSettings,
): DayCycleInfo {
  const isLoggedPeriod = periods.some((p) =>
    periodCoversDate(p, dateKey, settings.averagePeriodLength),
  )

  const cycleDay = getCycleDay(dateKey, periods)

  let isPredictedPeriod = false

  const lastStart = lastPeriodStart(periods)
  if (lastStart) {
    const cycleLen = Math.max(2, settings.averageCycleLength)
    const periodLen = Math.max(1, settings.averagePeriodLength)
    const horizon = toDateKey(addDays(parseISO(dateKey), cycleLen * 3))

    let cycleStart = parseISO(lastStart)
    for (let i = 0; i < 24; i++) {
      const cs = toDateKey(cycleStart)
      if (cs > horizon) break

      if (i > 0) {
        const pe = toDateKey(addDays(cycleStart, periodLen - 1))
        if (dateKey >= cs && dateKey <= pe) {
          isPredictedPeriod = true
        }
      }

      cycleStart = addDays(cycleStart, cycleLen)
    }
  }

  if (isLoggedPeriod) {
    isPredictedPeriod = false
  }

  return {
    date: dateKey,
    isLoggedPeriod,
    isPredictedPeriod,
    cycleDay,
  }
}

export function matchesCycleRule(
  info: DayCycleInfo,
  rule: {
    cycleRule: string
    cycleDayFrom?: number
    cycleDayTo?: number
  },
): boolean {
  switch (rule.cycleRule) {
    case 'none':
    case undefined:
      return true
    case 'period_only':
      return info.isLoggedPeriod || info.isPredictedPeriod
    case 'phase':
      return true
    case 'cycle_day_range': {
      if (info.cycleDay == null) return false
      const from = rule.cycleDayFrom ?? 1
      const to = rule.cycleDayTo ?? from
      return info.cycleDay >= from && info.cycleDay <= to
    }
    default:
      return true
  }
}

export function nextPredictedPeriodStart(
  periods: Period[],
  settings: CycleSettings,
): string | null {
  const last = lastPeriodStart(periods)
  if (!last) return null
  return toDateKey(addDays(parseISO(last), settings.averageCycleLength))
}

export function periodLengthDays(period: Period, defaultLen: number): number {
  if (!period.endDate) return defaultLen
  return (
    differenceInCalendarDays(
      parseISO(toDateKey(period.endDate)),
      parseISO(toDateKey(period.startDate)),
    ) + 1
  )
}
