import { addDays, parseISO } from 'date-fns'
import type { CycleSettings, Period } from '../types'
import { cycleWindowForDate, lastPeriodStart } from './cycle'
import { toDateKey } from './dates'

/**
 * Inclusive date range for expanding planned doses so Cycle and Month
 * see today, the selected day, the selected cycle window, and the latest cycle.
 */
export function doseExpansionRange(args: {
  today: string
  selectedDate: string
  periods: Period[]
  settings: CycleSettings
  extraFrom?: string[]
  extraTo?: string[]
}): { from: string; to: string } {
  const { today, selectedDate, periods, settings, extraFrom = [], extraTo = [] } =
    args

  const selectedWindow = cycleWindowForDate(selectedDate, periods, settings)
  const selectedWindowEnd = toDateKey(
    addDays(parseISO(selectedWindow.start), selectedWindow.length - 1),
  )
  const latestCycleStart = lastPeriodStart(periods)
  const latestCycleLen = Math.max(
    settings.averagePeriodLength + 2,
    settings.averageCycleLength,
  )
  const latestCycleEnd = latestCycleStart
    ? toDateKey(addDays(parseISO(latestCycleStart), latestCycleLen - 1))
    : null

  const fromKeys = [
    today,
    selectedDate,
    selectedWindow.start,
    ...(latestCycleStart ? [latestCycleStart] : []),
    ...extraFrom,
  ].sort()
  const toKeys = [
    today,
    selectedDate,
    selectedWindowEnd,
    ...(latestCycleEnd ? [latestCycleEnd] : []),
    ...extraTo,
  ].sort()

  return { from: fromKeys[0]!, to: toKeys[toKeys.length - 1]! }
}
