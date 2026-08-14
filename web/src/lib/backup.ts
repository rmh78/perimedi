import { db, DEFAULT_CYCLE_SETTINGS, ensureCycleSettings } from '../db/database'
import type { ExportPayload } from '../types'

export async function exportAllData(): Promise<ExportPayload> {
  const settings = await ensureCycleSettings()
  const [medications, schedules, doseLogs, remarks, periods] = await Promise.all([
    db.medications.toArray(),
    db.schedules.toArray(),
    db.doseLogs.toArray(),
    db.remarks.toArray(),
    db.periods.toArray(),
  ])

  return {
    version: 1,
    exportedAt: new Date().toISOString(),
    medications,
    schedules,
    doseLogs,
    remarks,
    cycleSettings: settings,
    periods,
  }
}

export async function importAllData(payload: ExportPayload): Promise<void> {
  if (payload.version !== 1) {
    throw new Error('Unsupported backup version')
  }

  await db.transaction('rw', db.tables, async () => {
    await Promise.all([
      db.medications.clear(),
      db.schedules.clear(),
      db.doseLogs.clear(),
      db.remarks.clear(),
      db.periods.clear(),
    ])

    if (payload.medications?.length) await db.medications.bulkAdd(payload.medications)
    if (payload.schedules?.length) await db.schedules.bulkAdd(payload.schedules)
    if (payload.doseLogs?.length) await db.doseLogs.bulkAdd(payload.doseLogs)
    if (payload.remarks?.length) await db.remarks.bulkAdd(payload.remarks)
    if (payload.periods?.length) await db.periods.bulkAdd(payload.periods)
    await db.cycleSettings.put(payload.cycleSettings ?? DEFAULT_CYCLE_SETTINGS)
  })
}

export function downloadJson(payload: ExportPayload, filename = 'perimedi-backup.json') {
  const blob = new Blob([JSON.stringify(payload, null, 2)], {
    type: 'application/json',
  })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}
