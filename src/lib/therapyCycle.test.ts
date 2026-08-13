import { describe, expect, it } from 'vitest'
import type { Schedule, TherapyCycle } from '../types'
import {
  describeTherapyCycle,
  getScheduleTimes,
  getTherapyCycle,
  matchTherapyCycle,
  normalizeTherapyCycle,
  normalizeTimes,
} from './therapyCycle'

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

const onOff: TherapyCycle = {
  enabled: true,
  mode: 'on_off_days',
  anchorDate: '2026-08-01',
  onDays: 3,
  offDays: 2,
}

describe('getScheduleTimes', () => {
  it('uses times when present and pads hour', () => {
    expect(
      getScheduleTimes(sched({ times: ['8:00', '20:30'] })),
    ).toEqual(['08:00', '20:30'])
  })

  it('falls back to timeOfDay, then 08:00', () => {
    expect(getScheduleTimes(sched({ timeOfDay: '9:15' }))).toEqual(['09:15'])
    expect(
      getScheduleTimes(sched({ timeOfDay: '', times: [] })),
    ).toEqual(['08:00'])
  })
})

describe('getTherapyCycle', () => {
  it('returns the enabled therapyCycle', () => {
    expect(getTherapyCycle(sched({ therapyCycle: onOff }))).toEqual(onOff)
  })

  it('migrates a legacy weekPattern to week_slots', () => {
    const cycle = getTherapyCycle(
      sched({
        startDate: '2026-07-01',
        weekPattern: {
          enabled: true,
          anchorDate: '2026-07-06',
          slots: [
            { take: true, doseLabel: '100 mg' },
            { take: false },
          ],
        },
      }),
    )
    expect(cycle).toMatchObject({
      enabled: true,
      mode: 'week_slots',
      anchorDate: '2026-07-06',
      onDays: 7,
      offDays: 7,
    })
    expect(cycle?.slots).toHaveLength(2)
  })

  it('returns null when neither therapy nor legacy pattern is enabled', () => {
    expect(getTherapyCycle(sched())).toBeNull()
  })
})

describe('matchTherapyCycle', () => {
  it('returns null for continuous or disabled cycles', () => {
    expect(
      matchTherapyCycle(
        sched({
          therapyCycle: { ...onOff, mode: 'continuous' },
        }),
        '2026-08-01',
      ),
    ).toBeNull()
    expect(matchTherapyCycle(sched(), '2026-08-01')).toBeNull()
  })

  it('is before_start when the date is earlier than the anchor', () => {
    const match = matchTherapyCycle(
      sched({ therapyCycle: onOff }),
      '2026-07-31',
    )
    expect(match).toEqual({ take: false, phase: 'before_start' })
  })

  it('applies then pauses for on_off_days', () => {
    const s = sched({ therapyCycle: onOff })
    // 3 on / 2 off from 2026-08-01
    expect(matchTherapyCycle(s, '2026-08-01')).toMatchObject({
      take: true,
      phase: 'apply',
      dayInBlock: 0,
    })
    expect(matchTherapyCycle(s, '2026-08-03')).toMatchObject({
      take: true,
      phase: 'apply',
      dayInBlock: 2,
    })
    expect(matchTherapyCycle(s, '2026-08-04')).toMatchObject({
      take: false,
      phase: 'pause',
      dayInBlock: 3,
    })
    expect(matchTherapyCycle(s, '2026-08-06')).toMatchObject({
      take: true,
      phase: 'apply',
      dayInBlock: 0,
    })
  })

  it('treats offDays 0 as continuous apply', () => {
    const match = matchTherapyCycle(
      sched({
        therapyCycle: { ...onOff, offDays: 0 },
      }),
      '2026-08-10',
    )
    expect(match).toMatchObject({ take: true, phase: 'continuous' })
  })

  it('treats onDays 0 as a permanent pause', () => {
    const match = matchTherapyCycle(
      sched({
        therapyCycle: { ...onOff, onDays: 0 },
      }),
      '2026-08-02',
    )
    expect(match).toMatchObject({ take: false, phase: 'pause' })
  })

  it('follows week_slots take and dose per week', () => {
    const s = sched({
      therapyCycle: {
        enabled: true,
        mode: 'week_slots',
        anchorDate: '2026-08-03',
        onDays: 14,
        offDays: 7,
        slots: [
          { take: true, doseLabel: '100 mg', name: 'Week 1' },
          { take: true, doseLabel: '50 mg', name: 'Week 2' },
          { take: false, name: 'Pause' },
        ],
      },
    })
    expect(matchTherapyCycle(s, '2026-08-03')).toMatchObject({
      take: true,
      phase: 'apply',
      slotIndex: 0,
      doseLabel: '100 mg',
    })
    expect(matchTherapyCycle(s, '2026-08-10')).toMatchObject({
      take: true,
      phase: 'apply',
      slotIndex: 1,
      doseLabel: '50 mg',
    })
    expect(matchTherapyCycle(s, '2026-08-17')).toMatchObject({
      take: false,
      phase: 'pause',
      slotIndex: 2,
    })
    expect(matchTherapyCycle(s, '2026-08-24')).toMatchObject({
      take: true,
      slotIndex: 0,
      doseLabel: '100 mg',
    })
  })
})

describe('normalizeTherapyCycle', () => {
  it('drops disabled, continuous, and pause-less day cycles', () => {
    expect(
      normalizeTherapyCycle(
        { enabled: false, mode: 'on_off_days', onDays: 21, offDays: 7 },
        '2026-08-01',
      ),
    ).toBeUndefined()
    expect(
      normalizeTherapyCycle(
        { enabled: true, mode: 'continuous', onDays: 0, offDays: 0 },
        '2026-08-01',
      ),
    ).toBeUndefined()
    expect(
      normalizeTherapyCycle(
        { enabled: true, mode: 'on_off_days', onDays: 21, offDays: 0 },
        '2026-08-01',
      ),
    ).toBeUndefined()
  })

  it('keeps on_off_days with a pause and week_slots with slots', () => {
    expect(
      normalizeTherapyCycle(
        { enabled: true, mode: 'on_off_days', onDays: 21, offDays: 7 },
        '2026-08-01',
      ),
    ).toMatchObject({
      enabled: true,
      mode: 'on_off_days',
      onDays: 21,
      offDays: 7,
      anchorDate: '2026-08-01',
    })
    expect(
      normalizeTherapyCycle(
        {
          enabled: true,
          mode: 'week_slots',
          slots: [{ take: true, doseLabel: ' 2 mg ' }, { take: false }],
        },
        '2026-08-01',
      ),
    ).toMatchObject({
      mode: 'week_slots',
      onDays: 7,
      offDays: 7,
    })
  })
})

describe('normalizeTimes', () => {
  it('dedupes, pads, and sorts clock times', () => {
    expect(normalizeTimes(['20:00', '8:00', '08:00'], '09:00')).toEqual([
      '08:00',
      '20:00',
    ])
  })

  it('falls back when nothing usable remains', () => {
    expect(normalizeTimes([], '9:00')).toEqual(['09:00'])
  })
})

describe('describeTherapyCycle', () => {
  it('describes continuous, on/off, and week slots', () => {
    expect(describeTherapyCycle(sched())).toBe('Continuous')
    expect(
      describeTherapyCycle(sched({ therapyCycle: onOff })),
    ).toBe('Apply 3 days · pause 2 days')
    expect(
      describeTherapyCycle(
        sched({
          therapyCycle: {
            enabled: true,
            mode: 'week_slots',
            anchorDate: '2026-08-01',
            onDays: 14,
            offDays: 7,
            slots: [{ take: true }, { take: true }, { take: false }],
          },
        }),
      ),
    ).toBe('Week slots · 2 on / 1 off')
  })
})
