import { addDays, subDays } from 'date-fns'
import { db, DEFAULT_CYCLE_SETTINGS, ensureCycleSettings } from '../db/database'
import type { Medication, Period, Remark, Schedule } from '../types'
import { createId } from './id'
import { toDateKey } from './dates'

/**
 * Demo dataset for a woman in perimenopause:
 * irregular cycles, HRT-style patterns, common supplements, typical symptoms.
 * Fictional — not medical advice.
 */
export async function loadSampleData(): Promise<void> {
  await db.transaction('rw', db.tables, async () => {
    await Promise.all([
      db.medications.clear(),
      db.schedules.clear(),
      db.doseLogs.clear(),
      db.remarks.clear(),
      db.periods.clear(),
    ])

    // Slightly longer / more variable cycles are common in perimenopause
    await db.cycleSettings.put({
      id: 'default',
      averageCycleLength: 35,
      averagePeriodLength: 6,
    })

    const today = new Date()
    const now = new Date().toISOString()
    // Progesterone “pack” started 12 days ago (mid-cycle style demo)
    const progStart = toDateKey(subDays(today, 12))
    // Estradiol continuous from earlier
    const e2Start = toDateKey(subDays(today, 60))

    const meds: Medication[] = [
      {
        id: createId(),
        name: 'Estradiol gel',
        form: 'CREAM',
        doseLabel: '1 pump',
        instructions: 'Apply to clean dry skin in the morning (arms/thighs)',
        color: '#9b6fc9',
        createdAt: now,
      },
      {
        id: createId(),
        name: 'Micronized progesterone',
        form: 'PILL',
        doseLabel: '100 mg',
        instructions: 'At bedtime; 14 days on, then pause (demo cyclic plan)',
        color: '#d43d6c',
        createdAt: now,
      },
      {
        id: createId(),
        name: 'Magnesium glycinate',
        form: 'PILL',
        doseLabel: '200 mg',
        instructions: 'Evening — may help sleep and muscle tension',
        color: '#0d9488',
        createdAt: now,
      },
      {
        id: createId(),
        name: 'Vitamin D3',
        form: 'PILL',
        doseLabel: '2000 IU',
        instructions: 'With breakfast and a little fat',
        color: '#c97b3a',
        createdAt: now,
      },
      {
        id: createId(),
        name: 'Iron bisglycinate',
        form: 'PILL',
        doseLabel: '25 mg',
        instructions: 'Only on heavier flow days if advised by clinician',
        color: '#ea580c',
        createdAt: now,
      },
      {
        id: createId(),
        name: 'Vaginal moisturizer',
        form: 'CREAM',
        doseLabel: 'Thin application',
        instructions: 'A few evenings per week',
        color: '#5b8fd9',
        createdAt: now,
      },
    ]

    await db.medications.bulkAdd(meds)

    const [
      estradiol,
      progesterone,
      magnesium,
      vitaminD,
      iron,
      vaginal,
    ] = meds

    const schedules: Schedule[] = [
      // Continuous estrogen
      {
        id: createId(),
        medicationId: estradiol.id,
        daysOfWeek: [],
        timeOfDay: '07:30',
        times: ['07:30'],
        active: true,
        startDate: e2Start,
        cycleRule: 'none',
      },
      // Cyclic progesterone: 14 days on / 14 days off (common peri pattern demo)
      {
        id: createId(),
        medicationId: progesterone.id,
        daysOfWeek: [],
        timeOfDay: '21:00',
        times: ['21:00'],
        doseLabel: '100 mg',
        active: true,
        startDate: progStart,
        cycleRule: 'none',
        therapyCycle: {
          enabled: true,
          mode: 'on_off_days',
          anchorDate: progStart,
          onDays: 14,
          offDays: 14,
        },
      },
      // Magnesium nightly
      {
        id: createId(),
        medicationId: magnesium.id,
        daysOfWeek: [],
        timeOfDay: '21:30',
        times: ['21:30'],
        active: true,
        cycleRule: 'none',
      },
      // Vitamin D morning
      {
        id: createId(),
        medicationId: vitaminD.id,
        daysOfWeek: [],
        timeOfDay: '08:00',
        times: ['08:00'],
        active: true,
        cycleRule: 'none',
      },
      // Iron only around period
      {
        id: createId(),
        medicationId: iron.id,
        daysOfWeek: [],
        timeOfDay: '12:00',
        times: ['12:00'],
        active: true,
        cycleRule: 'period_only',
      },
      // Vaginal moisturizer Mon / Wed / Fri
      {
        id: createId(),
        medicationId: vaginal.id,
        daysOfWeek: [1, 3, 5],
        timeOfDay: '22:00',
        times: ['22:00'],
        active: true,
        cycleRule: 'none',
      },
    ]

    await db.schedules.bulkAdd(schedules)

    // Irregular peri cycles: longer gaps, variable flow length
    const p1Start = subDays(today, 78)
    const p2Start = subDays(today, 41)
    const p3Start = subDays(today, 8)

    const periods: Period[] = [
      {
        id: createId(),
        startDate: toDateKey(p1Start),
        endDate: toDateKey(addDays(p1Start, 7)),
        flowNote: 'heavy',
        notes: 'Heavier than usual; clots day 2–3',
      },
      {
        id: createId(),
        startDate: toDateKey(p2Start),
        endDate: toDateKey(addDays(p2Start, 5)),
        flowNote: 'medium',
        notes: 'Cycle stretched ~37 days',
      },
      {
        id: createId(),
        startDate: toDateKey(p3Start),
        endDate: toDateKey(addDays(p3Start, 4)),
        flowNote: 'light',
        notes: 'Shorter, lighter bleed',
      },
    ]
    await db.periods.bulkAdd(periods)

    const remarks: Remark[] = [
      {
        id: createId(),
        occurredOn: toDateKey(subDays(today, 2)),
        kind: 'cycle',
        body: 'Night sweats twice; woke at 3 a.m.',
        createdAt: now,
      },
      {
        id: createId(),
        occurredOn: toDateKey(subDays(today, 1)),
        kind: 'cycle',
        body: 'Hot flush after lunch; lasted ~3 minutes.',
        createdAt: now,
      },
      {
        id: createId(),
        occurredOn: toDateKey(today),
        kind: 'cycle',
        body: 'Brain fog mid-morning; hard to focus.',
        createdAt: now,
      },
      {
        id: createId(),
        medicationId: progesterone.id,
        occurredOn: toDateKey(subDays(today, 3)),
        kind: 'side_effect',
        body: 'Sleepy next morning after progesterone — took earlier at 20:30.',
        createdAt: now,
      },
      {
        id: createId(),
        medicationId: estradiol.id,
        occurredOn: toDateKey(subDays(today, 5)),
        kind: 'side_effect',
        body: 'Mild breast tenderness; noted for next visit.',
        createdAt: now,
      },
      {
        id: createId(),
        occurredOn: toDateKey(p3Start),
        kind: 'cycle',
        body: 'Cramps day 1, milder than last cycle.',
        createdAt: now,
      },
      {
        id: createId(),
        occurredOn: toDateKey(addDays(p3Start, 1)),
        kind: 'cycle',
        body: 'Joint stiffness in hands in the morning.',
        createdAt: now,
      },
      {
        id: createId(),
        occurredOn: toDateKey(subDays(today, 6)),
        kind: 'note',
        body: 'Mood dip late afternoon; short walk helped.',
        createdAt: now,
      },
    ]

    await db.remarks.bulkAdd(remarks)
  })

  await ensureCycleSettings()
}

export async function clearAllData(): Promise<void> {
  await db.transaction('rw', db.tables, async () => {
    await Promise.all([
      db.medications.clear(),
      db.schedules.clear(),
      db.doseLogs.clear(),
      db.remarks.clear(),
      db.periods.clear(),
    ])
    await db.cycleSettings.put(DEFAULT_CYCLE_SETTINGS)
  })
}
