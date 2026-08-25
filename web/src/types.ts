export type MedForm = 'PILL' | 'CREAM' | 'DROPS' | 'INJECTION' | 'OTHER'

export type DoseStatus = 'pending' | 'taken' | 'skipped'

export type CycleRule = 'none' | 'period_only' | 'cycle_day_range'

export type RemarkKind = 'side_effect' | 'note' | 'cycle' | 'other'

export type FlowNote = 'spotting' | 'light' | 'medium' | 'heavy'

export interface Medication {
  id: string
  name: string
  form: MedForm
  doseLabel: string
  instructions?: string
  /** Hex color for icon, dose bands, and taken marks (e.g. #d43d6c) */
  color?: string
  createdAt: string
}

/**
 * One week inside an advanced week-slot therapy block.
 */
export interface WeekPatternSlot {
  take: boolean
  doseLabel?: string
  name?: string
}

/** @deprecated Prefer TherapyCycle — still read for older saved data */
export interface WeekPattern {
  enabled: boolean
  anchorDate: string
  slots: WeekPatternSlot[]
}

/**
 * Apple Health–style cyclic therapy plan.
 * - continuous: no on/off block
 * - on_off_days: apply N days, pause M days, repeat from anchor
 * - week_slots: advanced per-week on/off (+ optional dose per week)
 */
export type TherapyCycleMode = 'continuous' | 'on_off_days' | 'week_slots'

export interface TherapyCycle {
  enabled: boolean
  mode: TherapyCycleMode
  /** Start of first "apply" phase (YYYY-MM-DD) */
  anchorDate: string
  /** Days to take meds (e.g. 21) — used when mode is on_off_days */
  onDays: number
  /** Days to pause (e.g. 7); 0 = no pause */
  offDays: number
  /** Advanced week-based slots (mode week_slots) */
  slots?: WeekPatternSlot[]
}

export interface Schedule {
  id: string
  medicationId: string
  /** 0=Sun … 6=Sat; empty = every day */
  daysOfWeek: number[]
  /** Primary time HH:mm (always set; mirrors times[0]) */
  timeOfDay: string
  /** Optional multiple times; if absent, use [timeOfDay] */
  times?: string[]
  doseLabel?: string
  active: boolean
  startDate?: string
  endDate?: string
  /** Menstrual-cycle alignment */
  cycleRule: CycleRule
  cycleDayFrom?: number
  cycleDayTo?: number
  /** Apple-style apply/pause cycle */
  therapyCycle?: TherapyCycle
  /** @deprecated migrated from older builds */
  weekPattern?: WeekPattern
}

export type TherapyPresetId =
  | 'continuous'
  | '21_7'
  | '14_7'
  | '7_7'
  | '5_2'
  | 'custom_days'
  | 'week_slots'

export const THERAPY_PRESETS: {
  id: TherapyPresetId
  label: string
  hint: string
  mode: TherapyCycleMode
  onDays: number
  offDays: number
  slots?: WeekPatternSlot[] | null
}[] = [
  {
    id: 'continuous',
    label: 'Continuous (no pause)',
    hint: 'Take on every matching day — no cyclic pause',
    mode: 'continuous',
    onDays: 0,
    offDays: 0,
    slots: null,
  },
  {
    id: '21_7',
    label: '21 days on · 7 days pause',
    hint: 'Classic pack / many hormone schedules',
    mode: 'on_off_days',
    onDays: 21,
    offDays: 7,
  },
  {
    id: '14_7',
    label: '14 days on · 7 days pause',
    hint: 'Two weeks active, one week off',
    mode: 'on_off_days',
    onDays: 14,
    offDays: 7,
  },
  {
    id: '7_7',
    label: '7 days on · 7 days pause',
    hint: 'Alternate weeks',
    mode: 'on_off_days',
    onDays: 7,
    offDays: 7,
  },
  {
    id: '5_2',
    label: '5 days on · 2 days pause',
    hint: 'Weekday-style block (still calendar days from start)',
    mode: 'on_off_days',
    onDays: 5,
    offDays: 2,
  },
  {
    id: 'custom_days',
    label: 'Custom days…',
    hint: 'Set your own apply / pause day counts',
    mode: 'on_off_days',
    onDays: 21,
    offDays: 7,
  },
  {
    id: 'week_slots',
    label: 'Advanced week slots…',
    hint: 'Per-week on/off and optional dose per week',
    mode: 'week_slots',
    onDays: 21,
    offDays: 7,
    slots: [
      { take: true, name: 'Week 1', doseLabel: '100 mg' },
      { take: true, name: 'Week 2', doseLabel: '75 mg' },
      { take: true, name: 'Week 3', doseLabel: '50 mg' },
      { take: false, name: 'Pause' },
    ],
  },
]

export interface DoseLog {
  id: string
  medicationId: string
  scheduleId?: string
  plannedFor: string
  status: DoseStatus
  confirmedAt?: string
  skipReason?: string
}

export interface Remark {
  id: string
  medicationId?: string
  occurredOn: string
  kind: RemarkKind
  body: string
  createdAt: string
}

export interface CycleSettings {
  id: 'default'
  averageCycleLength: number
  averagePeriodLength: number
  tracksPeriods: boolean
}

export interface Period {
  id: string
  startDate: string
  endDate?: string
  flowNote?: FlowNote
  notes?: string
}

export interface ExportPayload {
  version: 1
  exportedAt: string
  medications: Medication[]
  schedules: Schedule[]
  doseLogs: DoseLog[]
  remarks: Remark[]
  cycleSettings: CycleSettings
  periods: Period[]
}

export interface DayCycleInfo {
  date: string
  isLoggedPeriod: boolean
  isPredictedPeriod: boolean
  cycleDay: number | null
}

export interface PlannedDose {
  key: string
  date: string
  timeOfDay: string
  medication: Medication
  schedule: Schedule
  doseLabel: string
  log?: DoseLog
  status: DoseStatus
}

export const MED_FORM_LABELS: Record<MedForm, string> = {
  PILL: 'Pill',
  CREAM: 'Cream',
  DROPS: 'Drops',
  INJECTION: 'Injection',
  OTHER: 'Other',
}

export const WEEKDAY_SHORT = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
