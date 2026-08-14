import type {
  CycleRule,
  Schedule,
  TherapyPresetId,
  WeekPatternSlot,
} from '../types'
import { todayKey } from './dates'
import { getScheduleTimes, getTherapyCycle } from './therapyCycle'

export type SchedFormState = {
  daysOfWeek: number[]
  times: string[]
  doseLabel: string
  active: boolean
  startDate: string
  endDate: string
  cycleRule: CycleRule
  cycleDayFrom: number
  cycleDayTo: number
  cyclic: boolean
  therapyPreset: TherapyPresetId
  onDays: number
  offDays: number
  anchorDate: string
  weekSlots: WeekPatternSlot[]
}

export function freshScheduleForm(): SchedFormState {
  const t = todayKey()
  return {
    daysOfWeek: [],
    times: ['20:00'],
    doseLabel: '',
    active: true,
    startDate: t,
    endDate: '',
    cycleRule: 'none',
    cycleDayFrom: 1,
    cycleDayTo: 5,
    cyclic: false,
    therapyPreset: 'continuous',
    onDays: 21,
    offDays: 7,
    anchorDate: t,
    weekSlots: [
      { take: true, name: 'Week 1', doseLabel: '100 mg' },
      { take: true, name: 'Week 2', doseLabel: '75 mg' },
      { take: true, name: 'Week 3', doseLabel: '50 mg' },
      { take: false, name: 'Pause' },
    ],
  }
}

export function scheduleToForm(s: Schedule): SchedFormState {
  const times = getScheduleTimes(s)
  const tc = getTherapyCycle(s)
  let therapyPreset: TherapyPresetId = 'continuous'
  let cyclic = false
  let onDays = 21
  let offDays = 7
  let weekSlots = freshScheduleForm().weekSlots

  if (tc?.enabled) {
    cyclic = true
    onDays = tc.onDays || 21
    offDays = tc.offDays || 7
    if (tc.mode === 'week_slots') {
      therapyPreset = 'week_slots'
      weekSlots = tc.slots?.length
        ? tc.slots.map((x) => ({ ...x }))
        : weekSlots
    } else if (tc.mode === 'on_off_days') {
      if (onDays === 21 && offDays === 7) therapyPreset = '21_7'
      else if (onDays === 14 && offDays === 7) therapyPreset = '14_7'
      else if (onDays === 7 && offDays === 7) therapyPreset = '7_7'
      else if (onDays === 5 && offDays === 2) therapyPreset = '5_2'
      else therapyPreset = 'custom_days'
    }
  }

  return {
    daysOfWeek: s.daysOfWeek,
    times,
    doseLabel: s.doseLabel ?? '',
    active: s.active,
    startDate: s.startDate ?? todayKey(),
    endDate: s.endDate ?? '',
    cycleRule: (s.cycleRule as string) === 'phase' ? 'none' : s.cycleRule,
    cycleDayFrom: s.cycleDayFrom ?? 1,
    cycleDayTo: s.cycleDayTo ?? 5,
    cyclic,
    therapyPreset,
    onDays,
    offDays,
    anchorDate: tc?.anchorDate ?? s.startDate ?? todayKey(),
    weekSlots,
  }
}
