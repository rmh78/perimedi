import { describe, expect, it } from 'vitest'
import type {
  CycleSettings,
  DoseLog,
  Medication,
  Period,
  Schedule,
} from '../types'
import { expandPlannedDoses, plannedForIso } from './schedule'

const settings: CycleSettings = {
  id: 'default',
  averageCycleLength: 28,
  averagePeriodLength: 5,
  tracksPeriods: true,
}

function med(partial: Partial<Medication> = {}): Medication {
  return {
    id: 'm1',
    name: 'Estrogen',
    form: 'PILL',
    doseLabel: '1 mg',
    createdAt: '2026-01-01T00:00:00',
    ...partial,
  }
}

function sched(partial: Partial<Schedule> = {}): Schedule {
  return {
    id: 's1',
    medicationId: 'm1',
    daysOfWeek: [],
    timeOfDay: '08:00',
    active: true,
    cycleRule: 'none',
    ...partial,
  }
}

function expand(partial: {
  from?: string
  to?: string
  medications?: Medication[]
  schedules?: Schedule[]
  doseLogs?: DoseLog[]
  periods?: Period[]
} = {}) {
  return expandPlannedDoses({
    from: partial.from ?? '2026-08-03',
    to: partial.to ?? '2026-08-09',
    medications: partial.medications ?? [med()],
    schedules: partial.schedules ?? [sched()],
    doseLogs: partial.doseLogs ?? [],
    periods: partial.periods ?? [],
    settings,
  })
}

describe('expandPlannedDoses', () => {
  it('emits one pending dose per day for an everyday schedule', () => {
    const doses = expand()
    expect(doses).toHaveLength(7)
    expect(doses.map((d) => d.date)).toEqual([
      '2026-08-03',
      '2026-08-04',
      '2026-08-05',
      '2026-08-06',
      '2026-08-07',
      '2026-08-08',
      '2026-08-09',
    ])
    expect(doses.every((d) => d.timeOfDay === '08:00')).toBe(true)
    expect(doses.every((d) => d.status === 'pending')).toBe(true)
    expect(doses[0]?.doseLabel).toBe('1 mg')
  })

  it('keeps only matching weekdays when daysOfWeek is set', () => {
    // 2026-08-03 is Monday. Keep Mon (1) and Wed (3).
    const doses = expand({
      schedules: [sched({ daysOfWeek: [1, 3] })],
    })
    expect(doses.map((d) => d.date)).toEqual([
      '2026-08-03',
      '2026-08-05',
    ])
  })

  it('skips inactive schedules and unknown medications', () => {
    const inactive = expand({
      schedules: [sched({ active: false })],
    })
    expect(inactive).toEqual([])

    const missingMed = expand({
      medications: [med({ id: 'other' })],
    })
    expect(missingMed).toEqual([])
  })

  it('respects schedule startDate and endDate inclusive', () => {
    const doses = expand({
      schedules: [
        sched({ startDate: '2026-08-05', endDate: '2026-08-07' }),
      ],
    })
    expect(doses.map((d) => d.date)).toEqual([
      '2026-08-05',
      '2026-08-06',
      '2026-08-07',
    ])
  })

  it('expands multiple times and prefers schedule doseLabel', () => {
    const doses = expand({
      from: '2026-08-03',
      to: '2026-08-03',
      schedules: [
        sched({
          timeOfDay: '08:00',
          times: ['08:00', '20:00'],
          doseLabel: '2 mg',
        }),
      ],
    })
    expect(doses.map((d) => d.timeOfDay)).toEqual(['08:00', '20:00'])
    expect(doses.every((d) => d.doseLabel === '2 mg')).toBe(true)
  })

  it('attaches a matching dose log and uses its status', () => {
    const log: DoseLog = {
      id: 'log1',
      medicationId: 'm1',
      scheduleId: 's1',
      plannedFor: '2026-08-03T08:00:00',
      status: 'taken',
    }
    const doses = expand({
      from: '2026-08-03',
      to: '2026-08-03',
      doseLogs: [log],
    })
    expect(doses).toHaveLength(1)
    expect(doses[0]?.status).toBe('taken')
    expect(doses[0]?.log?.id).toBe('log1')
  })

  it('skips therapy pause days for an on/off cycle', () => {
    const doses = expand({
      from: '2026-08-03',
      to: '2026-08-09',
      schedules: [
        sched({
          therapyCycle: {
            enabled: true,
            mode: 'on_off_days',
            anchorDate: '2026-08-03',
            onDays: 3,
            offDays: 4,
          },
        }),
      ],
    })
    expect(doses.map((d) => d.date)).toEqual([
      '2026-08-03',
      '2026-08-04',
      '2026-08-05',
    ])
  })

  it('limits period_only schedules to logged or predicted period days', () => {
    const periods: Period[] = [
      { id: 'p1', startDate: '2026-08-03', endDate: '2026-08-05' },
    ]
    const doses = expand({
      from: '2026-08-03',
      to: '2026-08-09',
      periods,
      schedules: [sched({ cycleRule: 'period_only' })],
    })
    expect(doses.map((d) => d.date)).toEqual([
      '2026-08-03',
      '2026-08-04',
      '2026-08-05',
    ])
  })
})

describe('plannedForIso', () => {
  it('combines a date key and clock time', () => {
    expect(plannedForIso('2026-08-03', '08:00')).toBe('2026-08-03T08:00:00')
  })
})
