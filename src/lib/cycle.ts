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

/** Most recent period start on or before dateKey (defines cycle day for that date). */
export function periodStartOnOrBefore(
  dateKey: string,
  periods: Period[],
): string | null {
  const starts = periods
    .map((p) => toDateKey(p.startDate))
    .filter((s) => s <= dateKey)
    .sort((a, b) => b.localeCompare(a))
  return starts[0] ?? null
}

/**
 * Cycle window (start + length) that contains dateKey for the cycle diagram.
 * Uses the period that defines cycle day for the date; if the date falls past
 * averageCycleLength, the window is extended so the day remains visible.
 */
export function cycleWindowForDate(
  dateKey: string,
  periods: Period[],
  settings: CycleSettings,
): { start: string; length: number } {
  const baseLen = Math.max(
    2,
    settings.averagePeriodLength + 2,
    settings.averageCycleLength,
  )

  const start = periodStartOnOrBefore(dateKey, periods)
  if (start) {
    const dayIndex =
      differenceInCalendarDays(parseISO(dateKey), parseISO(start)) + 1
    // Keep selected day on the chart (cap so a far calendar pick stays usable)
    const length = Math.min(
      90,
      Math.max(baseLen, dayIndex > 0 ? dayIndex : baseLen),
    )
    return { start, length }
  }

  // Selected date is before any logged period: still show a window starting
  // at that date so the month calendar can drive selection.
  return { start: dateKey, length: baseLen }
}

export function getCycleDay(dateKey: string, periods: Period[]): number | null {
  const last = periodStartOnOrBefore(dateKey, periods)
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

export type CycleBoundaryMark = {
  isStart: boolean
  isEnd: boolean
}

/**
 * Cycle boundary markers for a calendar range.
 *
 * Rules:
 * - Cycle day 1 is always the first day of a period (logged or predicted).
 * - Cycle starts are only those period-start dates — never mid-bleed.
 * - Cycle end is the day before the next cycle start (or start + avgCycle − 1
 *   when there is no following start yet).
 */
export function cycleBoundaryMarkers(
  from: string,
  to: string,
  periods: Period[],
  settings: CycleSettings,
): Map<string, CycleBoundaryMark> {
  const cycleLen = Math.max(2, settings.averageCycleLength)
  const periodLen = Math.max(1, settings.averagePeriodLength)
  const starts = new Set<string>()

  // 1) Logged period starts = real cycle starts (day 1)
  for (const p of periods) {
    starts.add(toDateKey(p.startDate))
  }

  // 2) Predicted period starts after the latest logged period (same cadence
  //    as period prediction). Skip any date that falls inside a logged period
  //    so we never place a second "start" on blood days.
  const last = lastPeriodStart(periods)
  if (last) {
    let predictedStart = addDays(parseISO(last), cycleLen)
    for (let i = 0; i < 36; i++) {
      const key = toDateKey(predictedStart)
      if (key > to && i > 0) break
      const insideLoggedBleed = periods.some(
        (p) =>
          toDateKey(p.startDate) !== key &&
          periodCoversDate(p, key, periodLen),
      )
      if (!insideLoggedBleed && key >= from) {
        starts.add(key)
      } else if (!insideLoggedBleed) {
        starts.add(key) // keep for end-date calc even if before `from`
      }
      predictedStart = addDays(predictedStart, cycleLen)
    }
  }

  const sortedStarts = [...starts].sort((a, b) => a.localeCompare(b))
  const ends = new Set<string>()

  for (let i = 0; i < sortedStarts.length; i++) {
    const s = sortedStarts[i]
    const next = sortedStarts[i + 1]
    if (next) {
      // Cycle ends the day before the next period/cycle starts
      ends.add(toDateKey(addDays(parseISO(next), -1)))
    } else {
      ends.add(toDateKey(addDays(parseISO(s), cycleLen - 1)))
    }
  }

  const map = new Map<string, CycleBoundaryMark>()
  for (const s of sortedStarts) {
    if (s < from || s > to) continue
    map.set(s, { isStart: true, isEnd: ends.has(s) })
  }
  for (const e of ends) {
    if (e < from || e > to) continue
    const prev = map.get(e) ?? { isStart: false, isEnd: false }
    map.set(e, { isStart: prev.isStart, isEnd: true })
  }
  return map
}
