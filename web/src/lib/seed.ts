import { addDays, subDays } from 'date-fns'
import { db, DEFAULT_CYCLE_SETTINGS, ensureCycleSettings } from '../db/database'
import type { DoseLog, Medication, Period, Remark, Schedule } from '../types'
import { createId } from './id'
import { toDateKey } from './dates'
import { plannedForIso } from './schedule'

/**
 * Demo dataset for a woman in perimenopause:
 * irregular cycles, HRT-style patterns, common supplements, typical symptoms.
 * Fictional — not medical advice.
 *
 * Cycle sketch (relative to “today”) — lengths ~26–29d (near-typical range):
 *   Period A  · start today−64 · 6 bleed days · gap → next start 28d
 *   Period B  · start today−36 · 5 bleed days · gap → next start 27d
 *   Period C  · start today−9  · 5 bleed days · current cycle (today ≈ day 10)
 * Avg settings 28d cycle / 5d period.
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

    // Near-typical cycle length with mild peri variation in the sample
    await db.cycleSettings.put({
      id: 'default',
      averageCycleLength: 28,
      averagePeriodLength: 5,
      tracksPeriods: true,
    })

    const today = new Date()
    const now = new Date().toISOString()
    const todayKey = toDateKey(today)

    // --- Periods (non-overlapping; day 1 = first bleed day) ---
    // Inclusive length: end = start + (days − 1)
    // Gaps between starts: 28d then 27d (within 26–29 target)
    const p1Start = subDays(today, 64) // cycle A
    const p2Start = subDays(today, 36) // 28 days after p1
    const p3Start = subDays(today, 9) // 27 days after p2

    const periods: Period[] = [
      {
        id: createId(),
        startDate: toDateKey(p1Start),
        endDate: toDateKey(addDays(p1Start, 5)), // 6 days
        flowNote: 'heavy',
        notes: 'Heavier than usual; clots day 2–3',
      },
      {
        id: createId(),
        startDate: toDateKey(p2Start),
        endDate: toDateKey(addDays(p2Start, 4)), // 5 days
        flowNote: 'medium',
        notes: 'Cycle ~28 days from previous start',
      },
      {
        id: createId(),
        startDate: toDateKey(p3Start),
        endDate: toDateKey(addDays(p3Start, 4)), // 5 days; ended 4 days ago
        flowNote: 'light',
        notes: 'Slightly shorter cycle (~27d); lighter bleed',
      },
    ]

    // Continuous E2 from ~2 months ago; cyclic P “pack” started mid previous cycle
    const e2Start = toDateKey(subDays(today, 60))
    // Anchor progesterone ~day 15 of cycle B (after p2 bleed) — classic luteal-style timing demo
    const progStart = toDateKey(addDays(p2Start, 14))

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
        instructions: 'At bedtime; 14 days on, then pause (cyclic demo plan)',
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
      // Continuous estrogen (common with cyclic progesterone)
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
      // Cyclic progesterone: 14 on / 14 off from mid-cycle anchor
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
      {
        id: createId(),
        medicationId: magnesium.id,
        daysOfWeek: [],
        timeOfDay: '21:30',
        times: ['21:30'],
        active: true,
        startDate: e2Start,
        cycleRule: 'none',
      },
      {
        id: createId(),
        medicationId: vitaminD.id,
        daysOfWeek: [],
        timeOfDay: '08:00',
        times: ['08:00'],
        active: true,
        startDate: e2Start,
        cycleRule: 'none',
      },
      // Iron only on period days (logged + predicted)
      {
        id: createId(),
        medicationId: iron.id,
        daysOfWeek: [],
        timeOfDay: '12:00',
        times: ['12:00'],
        active: true,
        startDate: toDateKey(p1Start),
        cycleRule: 'period_only',
      },
      // Vaginal moisturizer Mon / Wed / Fri evenings
      {
        id: createId(),
        medicationId: vaginal.id,
        daysOfWeek: [1, 3, 5],
        timeOfDay: '22:00',
        times: ['22:00'],
        active: true,
        startDate: e2Start,
        cycleRule: 'none',
      },
    ]

    await db.schedules.bulkAdd(schedules)
    await db.periods.bulkAdd(periods)

    // --- Recent adherence logs (makes the chart look lived-in) ---
    const doseLogs: DoseLog[] = []
    const dailyMorning = [
      { med: estradiol, time: '07:30', scheduleId: schedules[0].id },
      { med: vitaminD, time: '08:00', scheduleId: schedules[3].id },
    ]
    const dailyEvening = [
      { med: magnesium, time: '21:30', scheduleId: schedules[2].id },
    ]

    for (let daysAgo = 6; daysAgo >= 0; daysAgo--) {
      const date = toDateKey(subDays(today, daysAgo))
      // Mornings mostly taken; miss one vitamin D day
      for (const { med, time, scheduleId } of dailyMorning) {
        const taken =
          !(med.id === vitaminD.id && daysAgo === 2) &&
          !(med.id === estradiol.id && daysAgo === 4)
        doseLogs.push({
          id: createId(),
          medicationId: med.id,
          scheduleId,
          plannedFor: plannedForIso(date, time),
          status: taken ? 'taken' : 'pending',
          confirmedAt: taken
            ? new Date(
                parseIsoLocal(date, time).getTime() + 15 * 60 * 1000,
              ).toISOString()
            : undefined,
        })
      }
      for (const { med, time, scheduleId } of dailyEvening) {
        const taken = daysAgo !== 1
        doseLogs.push({
          id: createId(),
          medicationId: med.id,
          scheduleId,
          plannedFor: plannedForIso(date, time),
          status: taken ? 'taken' : 'pending',
          confirmedAt: taken
            ? new Date(
                parseIsoLocal(date, time).getTime() + 20 * 60 * 1000,
              ).toISOString()
            : undefined,
        })
      }
    }

    // Progesterone taken on recent “on” days of the 14/14 pack
    for (let daysAgo = 5; daysAgo >= 0; daysAgo--) {
      const date = toDateKey(subDays(today, daysAgo))
      doseLogs.push({
        id: createId(),
        medicationId: progesterone.id,
        scheduleId: schedules[1].id,
        plannedFor: plannedForIso(date, '21:00'),
        status: daysAgo === 3 ? 'pending' : 'taken',
        confirmedAt:
          daysAgo === 3
            ? undefined
            : new Date(
                parseIsoLocal(date, '21:00').getTime() + 10 * 60 * 1000,
              ).toISOString(),
      })
    }

    // Iron on a couple of days during last period (p3)
    for (const offset of [0, 1, 2]) {
      const date = toDateKey(addDays(p3Start, offset))
      doseLogs.push({
        id: createId(),
        medicationId: iron.id,
        scheduleId: schedules[4].id,
        plannedFor: plannedForIso(date, '12:00'),
        status: 'taken',
        confirmedAt: new Date(
          parseIsoLocal(date, '12:00').getTime() + 30 * 60 * 1000,
        ).toISOString(),
      })
    }

    await db.doseLogs.bulkAdd(doseLogs)

    const remarks: Remark[] = [
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
        medicationId: progesterone.id,
        occurredOn: toDateKey(subDays(today, 3)),
        kind: 'side_effect',
        body: 'Sleepy next morning after progesterone — took earlier at 20:30.',
        createdAt: now,
      },
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
        occurredOn: todayKey,
        kind: 'cycle',
        body: 'Brain fog mid-morning; hard to focus.',
        createdAt: now,
      },
    ]

    await db.remarks.bulkAdd(remarks)
  })

  await ensureCycleSettings()
}

/** Local date + HH:mm → Date (for sample confirmedAt timestamps). */
function parseIsoLocal(dateKey: string, timeOfDay: string): Date {
  const [h, m] = timeOfDay.split(':').map(Number)
  const d = new Date(`${dateKey}T00:00:00`)
  d.setHours(h || 0, m || 0, 0, 0)
  return d
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
