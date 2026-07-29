import { eachDayOfInterval, parseISO } from 'date-fns'
import type {
  CycleSettings,
  DoseLog,
  Medication,
  Period,
  PlannedDose,
  Schedule,
} from '../types'
import { getDayCycleInfo, matchesCycleRule } from './cycle'
import { combineDateAndTime, toDateKey } from './dates'
import { getScheduleTimes, matchTherapyCycle } from './therapyCycle'

function logKey(scheduleId: string, dateKey: string, timeOfDay: string): string {
  return `${scheduleId}|${dateKey}|${timeOfDay}`
}

export function expandPlannedDoses(options: {
  from: string
  to: string
  medications: Medication[]
  schedules: Schedule[]
  doseLogs: DoseLog[]
  periods: Period[]
  settings: CycleSettings
}): PlannedDose[] {
  const {
    from,
    to,
    medications,
    schedules,
    doseLogs,
    periods,
    settings,
  } = options

  const medById = new Map(medications.map((m) => [m.id, m]))
  const logBySlot = new Map<string, DoseLog>()
  for (const log of doseLogs) {
    if (!log.scheduleId) continue
    const dateKey = toDateKey(log.plannedFor)
    const time = log.plannedFor.slice(11, 16) || '08:00'
    logBySlot.set(logKey(log.scheduleId, dateKey, time), log)
  }

  const days = eachDayOfInterval({
    start: parseISO(from),
    end: parseISO(to),
  })

  const result: PlannedDose[] = []

  for (const day of days) {
    const dateKey = toDateKey(day)
    const weekday = day.getDay()
    const cycleInfo = getDayCycleInfo(dateKey, periods, settings)

    for (const schedule of schedules) {
      if (!schedule.active) continue
      if (schedule.startDate && dateKey < toDateKey(schedule.startDate)) continue
      if (schedule.endDate && dateKey > toDateKey(schedule.endDate)) continue
      if (
        schedule.daysOfWeek.length > 0 &&
        !schedule.daysOfWeek.includes(weekday)
      ) {
        continue
      }
      if (!matchesCycleRule(cycleInfo, schedule)) continue

      const therapy = matchTherapyCycle(schedule, dateKey)
      if (therapy && !therapy.take) continue

      const med = medById.get(schedule.medicationId)
      if (!med) continue

      const times = getScheduleTimes(schedule)
      for (const timeOfDay of times) {
        const log = logBySlot.get(logKey(schedule.id, dateKey, timeOfDay))
        result.push({
          key: `${schedule.id}-${dateKey}-${timeOfDay}`,
          date: dateKey,
          timeOfDay,
          medication: med,
          schedule,
          doseLabel:
            therapy?.doseLabel || schedule.doseLabel || med.doseLabel,
          log,
          status: log?.status ?? 'pending',
        })
      }
    }
  }

  result.sort((a, b) => {
    const d = a.date.localeCompare(b.date)
    if (d !== 0) return d
    return (
      a.timeOfDay.localeCompare(b.timeOfDay) ||
      a.medication.name.localeCompare(b.medication.name)
    )
  })

  return result
}

export function plannedForIso(dateKey: string, timeOfDay: string): string {
  return combineDateAndTime(dateKey, timeOfDay)
}
