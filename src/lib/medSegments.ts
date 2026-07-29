import { addDays, parseISO } from 'date-fns'
import type { MedForm, PlannedDose } from '../types'
import { toDateKey } from './dates'

export type DoseDayCell = {
  cycleDay: number
  dateKey: string | null
  /** Combined dose label for that day (e.g. "100 mg" or "100 mg + 200 mg") */
  doseLabel: string
  statuses: Array<'pending' | 'taken' | 'skipped'>
}

export type DoseSegment = {
  fromDay: number
  toDay: number
  doseLabel: string
  /** Aggregate adherence for the segment */
  taken: number
  skipped: number
  pending: number
  total: number
}

export type MedLane = {
  medicationId: string
  name: string
  form: MedForm
  defaultDose: string
  days: DoseDayCell[]
  segments: DoseSegment[]
}

/**
 * Build one lane per medication with contiguous dose segments across cycle days.
 * Example: days 1–5 "100 mg", days 6–10 "200 mg".
 */
export function buildMedLanes(
  doses: PlannedDose[],
  cycleStart: string | null,
  cycleLen: number,
): MedLane[] {
  // dateKey -> cycleDay
  const dateToDay = new Map<string, number>()
  if (cycleStart) {
    for (let day = 1; day <= cycleLen; day++) {
      const key = toDateKey(addDays(parseISO(cycleStart), day - 1))
      dateToDay.set(key, day)
    }
  }

  type Acc = {
    medicationId: string
    name: string
    form: MedForm
    defaultDose: string
    /** cycleDay -> { dose labels set, statuses } */
    byDay: Map<
      number,
      { doses: Map<string, true>; statuses: Array<'pending' | 'taken' | 'skipped'> }
    >
  }

  const byMed = new Map<string, Acc>()

  for (const d of doses) {
    let cycleDay = dateToDay.get(d.date)
    // Without a logged period, fall back to nothing date-aligned —
    // still allow illustrative lanes only when we have cycleStart.
    if (cycleDay == null) continue
    if (cycleDay < 1 || cycleDay > cycleLen) continue

    let acc = byMed.get(d.medication.id)
    if (!acc) {
      acc = {
        medicationId: d.medication.id,
        name: d.medication.name,
        form: d.medication.form,
        defaultDose: d.medication.doseLabel,
        byDay: new Map(),
      }
      byMed.set(d.medication.id, acc)
    }

    let cell = acc.byDay.get(cycleDay)
    if (!cell) {
      cell = { doses: new Map(), statuses: [] }
      acc.byDay.set(cycleDay, cell)
    }
    cell.doses.set(d.doseLabel, true)
    cell.statuses.push(d.status)
  }

  const lanes: MedLane[] = []

  for (const acc of byMed.values()) {
    const days: DoseDayCell[] = []
    for (let day = 1; day <= cycleLen; day++) {
      const cell = acc.byDay.get(day)
      if (!cell) continue
      const doseLabel = [...cell.doses.keys()].sort().join(' + ')
      days.push({
        cycleDay: day,
        dateKey: cycleStart
          ? toDateKey(addDays(parseISO(cycleStart), day - 1))
          : null,
        doseLabel,
        statuses: cell.statuses,
      })
    }

    days.sort((a, b) => a.cycleDay - b.cycleDay)
    const segments = groupDoseSegments(days)
    if (segments.length === 0) continue

    lanes.push({
      medicationId: acc.medicationId,
      name: acc.name,
      form: acc.form,
      defaultDose: acc.defaultDose,
      days,
      segments,
    })
  }

  lanes.sort((a, b) => a.name.localeCompare(b.name))
  return lanes
}

function groupDoseSegments(days: DoseDayCell[]): DoseSegment[] {
  if (days.length === 0) return []

  const segments: DoseSegment[] = []
  let current: DoseSegment | null = null

  for (const day of days) {
    const taken = day.statuses.filter((s) => s === 'taken').length
    const skipped = day.statuses.filter((s) => s === 'skipped').length
    const pending = day.statuses.filter((s) => s === 'pending').length
    const total = day.statuses.length

    if (
      current &&
      current.doseLabel === day.doseLabel &&
      day.cycleDay === current.toDay + 1
    ) {
      current.toDay = day.cycleDay
      current.taken += taken
      current.skipped += skipped
      current.pending += pending
      current.total += total
    } else {
      if (current) segments.push(current)
      current = {
        fromDay: day.cycleDay,
        toDay: day.cycleDay,
        doseLabel: day.doseLabel,
        taken,
        skipped,
        pending,
        total,
      }
    }
  }
  if (current) segments.push(current)
  return segments
}

/** When no period is logged, invent cycle-day lanes from dose dates relative to today span — skip; use empty. */
export function buildIllustrativeEmptyLanes(): MedLane[] {
  return []
}
