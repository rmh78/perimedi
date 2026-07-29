import Dexie, { type Table } from 'dexie'
import type {
  CycleSettings,
  DoseLog,
  Medication,
  Period,
  Remark,
  Schedule,
} from '../types'

export class PeriMediDB extends Dexie {
  medications!: Table<Medication, string>
  schedules!: Table<Schedule, string>
  doseLogs!: Table<DoseLog, string>
  remarks!: Table<Remark, string>
  cycleSettings!: Table<CycleSettings, string>
  periods!: Table<Period, string>

  constructor() {
    super('perimedi')
    this.version(1).stores({
      medications: 'id, name, createdAt',
      schedules: 'id, medicationId, active',
      doseLogs: 'id, medicationId, scheduleId, plannedFor, status',
      remarks: 'id, medicationId, occurredOn, kind, createdAt',
      cycleSettings: 'id',
      periods: 'id, startDate, endDate',
    })
  }
}

export const db = new PeriMediDB()

export const DEFAULT_CYCLE_SETTINGS: CycleSettings = {
  id: 'default',
  averageCycleLength: 28,
  averagePeriodLength: 5,
}

export async function ensureCycleSettings(): Promise<CycleSettings> {
  const existing = await db.cycleSettings.get('default')
  if (existing) {
    return {
      id: 'default',
      averageCycleLength: existing.averageCycleLength ?? 28,
      averagePeriodLength: existing.averagePeriodLength ?? 5,
    }
  }
  await db.cycleSettings.put(DEFAULT_CYCLE_SETTINGS)
  return DEFAULT_CYCLE_SETTINGS
}
