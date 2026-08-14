import { db, DEFAULT_CYCLE_SETTINGS, ensureCycleSettings } from '../db/database'
import type {
  CycleSettings,
  DoseLog,
  Medication,
  Period,
  Remark,
  Schedule,
} from '../types'
import { useLiveQuery } from './useLiveQuery'

export function useMedications(): Medication[] {
  return useLiveQuery(() => db.medications.orderBy('name').toArray(), [], []) ?? []
}

export function useSchedules(): Schedule[] {
  return useLiveQuery(() => db.schedules.toArray(), [], []) ?? []
}

export function useDoseLogs(): DoseLog[] {
  return useLiveQuery(() => db.doseLogs.toArray(), [], []) ?? []
}

export function useRemarks(): Remark[] {
  return useLiveQuery(() => db.remarks.orderBy('occurredOn').reverse().toArray(), [], []) ?? []
}

export function usePeriods(): Period[] {
  return useLiveQuery(() => db.periods.orderBy('startDate').reverse().toArray(), [], []) ?? []
}

export function useCycleSettings(): CycleSettings {
  return (
    useLiveQuery(async () => ensureCycleSettings(), [], DEFAULT_CYCLE_SETTINGS) ??
    DEFAULT_CYCLE_SETTINGS
  )
}
