import { db } from './database'
import type {
  CycleRule,
  CycleSettings,
  DoseStatus,
  FlowNote,
  MedForm,
  RemarkKind,
  SymptomScore,
  TherapyCycle,
} from '../types'
import { allowsCount, type SymptomId } from '../lib/symptoms'
import { normalizeTimes } from '../lib/therapyCycle'
import { createId } from '../lib/id'
import { plannedForIso } from '../lib/schedule'
import { toDateKey } from '../lib/dates'

export async function upsertMedication(input: {
  id?: string
  name: string
  form: MedForm
  doseLabel: string
  instructions?: string
  color?: string
  remindersEnabled?: boolean
}): Promise<string> {
  const id = input.id ?? createId()
  const existing = input.id ? await db.medications.get(input.id) : undefined
  await db.medications.put({
    id,
    name: input.name.trim(),
    form: input.form,
    doseLabel: input.doseLabel.trim(),
    instructions: input.instructions?.trim() || undefined,
    color: input.color?.trim() || undefined,
    createdAt: existing?.createdAt ?? new Date().toISOString(),
    remindersEnabled: input.remindersEnabled ?? existing?.remindersEnabled ?? true,
  })
  return id
}

export async function deleteMedication(id: string): Promise<void> {
  await db.transaction(
    'rw',
    db.medications,
    db.schedules,
    db.doseLogs,
    db.remarks,
    async () => {
      await db.medications.delete(id)
      await db.schedules.where('medicationId').equals(id).delete()
      await db.doseLogs.where('medicationId').equals(id).delete()
      const remarks = await db.remarks.where('medicationId').equals(id).toArray()
      for (const r of remarks) {
        await db.remarks.update(r.id, { medicationId: undefined })
      }
    },
  )
}

export async function upsertSchedule(input: {
  id?: string
  medicationId: string
  daysOfWeek: number[]
  timeOfDay?: string
  times?: string[]
  doseLabel?: string
  active: boolean
  startDate?: string
  endDate?: string
  cycleRule: CycleRule
  cycleDayFrom?: number
  cycleDayTo?: number
  therapyCycle?: TherapyCycle
}): Promise<string> {
  const id = input.id ?? createId()
  const times = normalizeTimes(
    input.times ?? (input.timeOfDay ? [input.timeOfDay] : []),
    '08:00',
  )
  await db.schedules.put({
    id,
    medicationId: input.medicationId,
    daysOfWeek: input.daysOfWeek,
    timeOfDay: times[0],
    times,
    doseLabel: input.doseLabel?.trim() || undefined,
    active: input.active,
    startDate: input.startDate || undefined,
    endDate: input.endDate || undefined,
    cycleRule: input.cycleRule,
    cycleDayFrom: input.cycleDayFrom,
    cycleDayTo: input.cycleDayTo,
    therapyCycle: input.therapyCycle,
    weekPattern: undefined,
  })
  return id
}

export async function deleteSchedule(id: string): Promise<void> {
  await db.schedules.delete(id)
}

export async function setDoseStatus(input: {
  medicationId: string
  scheduleId: string
  date: string
  timeOfDay: string
  status: DoseStatus
  skipReason?: string
  existingLogId?: string
}): Promise<void> {
  const plannedFor = plannedForIso(input.date, input.timeOfDay)
  const id = input.existingLogId ?? createId()
  await db.doseLogs.put({
    id,
    medicationId: input.medicationId,
    scheduleId: input.scheduleId,
    plannedFor,
    status: input.status,
    confirmedAt:
      input.status === 'pending' ? undefined : new Date().toISOString(),
    skipReason:
      input.status === 'skipped' ? input.skipReason?.trim() || undefined : undefined,
  })
}

export async function addRemark(input: {
  medicationId?: string
  occurredOn: string
  kind: RemarkKind
  body: string
}): Promise<void> {
  await db.remarks.add({
    id: createId(),
    medicationId: input.medicationId || undefined,
    occurredOn: toDateKey(input.occurredOn),
    kind: input.kind,
    body: input.body.trim(),
    createdAt: new Date().toISOString(),
  })
}

export async function updateRemark(
  id: string,
  patch: { kind?: RemarkKind; body?: string },
): Promise<void> {
  const next: { kind?: RemarkKind; body?: string } = {}
  if (patch.kind) next.kind = patch.kind
  if (patch.body != null) next.body = patch.body.trim()
  if (Object.keys(next).length === 0) return
  await db.remarks.update(id, next)
}

export async function deleteRemark(id: string): Promise<void> {
  await db.remarks.delete(id)
}

export async function replaceDayScores(input: {
  date: string
  scores: { id: SymptomId; severity: number; count?: number }[]
  note?: string
  noteId?: string | null
}): Promise<void> {
  const date = toDateKey(input.date)
  const loggedAt = new Date().toISOString()
  const note = input.note?.trim() || undefined
  await db.transaction('rw', db.symptomScores, db.remarks, async () => {
    await db.symptomScores.where('date').equals(date).delete()
    const rows: SymptomScore[] = input.scores.map((row) => ({
      id: row.id,
      date,
      severity: Math.min(4, Math.max(0, row.severity)),
      count:
        allowsCount(row.id) && row.count != null
          ? Math.min(99, Math.max(0, row.count))
          : undefined,
      note,
      loggedAt,
      higherIsWorse: true,
    }))
    if (rows.length) await db.symptomScores.bulkAdd(rows)
    if (note) {
      if (input.noteId) {
        await db.remarks.update(input.noteId, { body: note, kind: 'note' })
      } else {
        const existing = await db.remarks
          .where('occurredOn')
          .equals(date)
          .filter((r) => r.kind === 'note')
          .first()
        if (existing) {
          await db.remarks.update(existing.id, { body: note })
        } else {
          await db.remarks.add({
            id: createId(),
            occurredOn: date,
            kind: 'note',
            body: note,
            createdAt: loggedAt,
          })
        }
      }
    } else if (input.noteId) {
      await db.remarks.delete(input.noteId)
    }
  })
}

export async function saveCycleSettings(
  patch: Partial<Omit<CycleSettings, 'id'>>,
): Promise<void> {
  const current = await ensureSettings()
  await db.cycleSettings.put({
    id: 'default',
    averageCycleLength: patch.averageCycleLength ?? current.averageCycleLength,
    averagePeriodLength:
      patch.averagePeriodLength ?? current.averagePeriodLength,
    tracksPeriods: patch.tracksPeriods ?? current.tracksPeriods,
  })
}

async function ensureSettings(): Promise<CycleSettings> {
  const existing = await db.cycleSettings.get('default')
  if (existing) {
    return {
      id: 'default',
      averageCycleLength: existing.averageCycleLength ?? 28,
      averagePeriodLength: existing.averagePeriodLength ?? 5,
      tracksPeriods: existing.tracksPeriods ?? true,
    }
  }
  return {
    id: 'default',
    averageCycleLength: 28,
    averagePeriodLength: 5,
    tracksPeriods: true,
  }
}

export async function upsertPeriod(input: {
  id?: string
  startDate: string
  endDate?: string
  flowNote?: FlowNote
  notes?: string
}): Promise<string> {
  const id = input.id ?? createId()
  await db.periods.put({
    id,
    startDate: toDateKey(input.startDate),
    endDate: input.endDate ? toDateKey(input.endDate) : undefined,
    flowNote: input.flowNote,
    notes: input.notes?.trim() || undefined,
  })
  return id
}

export async function deletePeriod(id: string): Promise<void> {
  await db.periods.delete(id)
}

export async function startPeriodToday(dateKey: string): Promise<void> {
  await upsertPeriod({ startDate: dateKey, flowNote: 'medium' })
}

export async function endOpenPeriods(dateKey: string): Promise<void> {
  const open = await db.periods.filter((p) => !p.endDate).toArray()
  for (const p of open) {
    if (toDateKey(p.startDate) <= dateKey) {
      await db.periods.update(p.id, { endDate: dateKey })
    }
  }
}
