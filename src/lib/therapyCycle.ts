import { addDays, differenceInCalendarDays, format, parseISO } from 'date-fns'
import type {
  Schedule,
  TherapyCycle,
  TherapyCycleMode,
  WeekPatternSlot,
} from '../types'
import { toDateKey } from './dates'

export type TherapyMatch = {
  take: boolean
  /** Position inside current block (0 .. on+off-1) for on_off_days */
  dayInBlock?: number
  /** Phase: applying or pausing */
  phase: 'apply' | 'pause' | 'continuous' | 'before_start'
  doseLabel?: string
  slotIndex?: number
}

/** Times for a schedule (multi-time support). */
export function getScheduleTimes(schedule: Schedule): string[] {
  if (schedule.times && schedule.times.length > 0) {
    return schedule.times.map(normalizeTime).filter(Boolean)
  }
  if (schedule.timeOfDay) return [normalizeTime(schedule.timeOfDay)]
  return ['08:00']
}

function normalizeTime(t: string): string {
  const m = t.trim().match(/^(\d{1,2}):(\d{2})/)
  if (!m) return t
  return `${m[1].padStart(2, '0')}:${m[2]}`
}

/** Resolve effective therapy cycle, migrating legacy weekPattern. */
export function getTherapyCycle(schedule: Schedule): TherapyCycle | null {
  if (schedule.therapyCycle?.enabled) {
    return schedule.therapyCycle
  }
  // Legacy weekPattern → week_slots
  const wp = schedule.weekPattern
  if (wp?.enabled && wp.slots?.length) {
    return {
      enabled: true,
      mode: 'week_slots',
      anchorDate: wp.anchorDate || schedule.startDate || toDateKey(new Date()),
      onDays: wp.slots.filter((s) => s.take).length * 7,
      offDays: wp.slots.filter((s) => !s.take).length * 7,
      slots: wp.slots,
    }
  }
  return null
}

export function resolveAnchor(schedule: Schedule, cycle: TherapyCycle): string {
  if (cycle.anchorDate) return toDateKey(cycle.anchorDate)
  if (schedule.startDate) return toDateKey(schedule.startDate)
  return toDateKey(new Date())
}

export function matchTherapyCycle(
  schedule: Schedule,
  dateKey: string,
): TherapyMatch | null {
  const cycle = getTherapyCycle(schedule)
  if (!cycle?.enabled || cycle.mode === 'continuous') return null

  const day = toDateKey(dateKey)
  const anchor = resolveAnchor(schedule, cycle)
  const daysSince = differenceInCalendarDays(parseISO(day), parseISO(anchor))

  if (daysSince < 0) {
    return { take: false, phase: 'before_start' }
  }

  if (cycle.mode === 'week_slots' && cycle.slots?.length) {
    return matchWeekSlots(cycle.slots, daysSince)
  }

  // on_off_days (default cyclic)
  const onDays = Math.max(0, Math.floor(cycle.onDays || 0))
  const offDays = Math.max(0, Math.floor(cycle.offDays || 0))
  if (onDays <= 0 && offDays <= 0) return null
  if (offDays <= 0) {
    return { take: true, phase: 'continuous', dayInBlock: daysSince }
  }
  if (onDays <= 0) {
    return { take: false, phase: 'pause', dayInBlock: daysSince % offDays }
  }

  const block = onDays + offDays
  const pos = daysSince % block
  const take = pos < onDays
  return {
    take,
    dayInBlock: pos,
    phase: take ? 'apply' : 'pause',
  }
}

function matchWeekSlots(slots: WeekPatternSlot[], daysSince: number): TherapyMatch {
  const weekNumber = Math.floor(daysSince / 7)
  const slotIndex = weekNumber % slots.length
  const slot = slots[slotIndex]
  return {
    take: slot.take,
    phase: slot.take ? 'apply' : 'pause',
    slotIndex,
    doseLabel: slot.take ? slot.doseLabel : undefined,
  }
}

export function describeTherapyCycle(
  schedule: Schedule,
  cycle?: TherapyCycle | null,
): string {
  const c = cycle ?? getTherapyCycle(schedule)
  if (!c?.enabled || c.mode === 'continuous') return 'Continuous'
  if (c.mode === 'week_slots' && c.slots?.length) {
    const on = c.slots.filter((s) => s.take).length
    const off = c.slots.length - on
    return `Week slots · ${on} on / ${off} off`
  }
  if (c.offDays <= 0) return `Apply ${c.onDays} days (no pause)`
  return `Apply ${c.onDays} days · pause ${c.offDays} days`
}

export type CyclePreview = {
  nextPauseStart: string | null
  nextApplyStart: string | null
  currently: 'apply' | 'pause' | 'continuous' | 'before_start'
  label: string
}

/** Preview next pause / apply from "today" (or refDate). */
export function previewTherapyCycle(
  schedule: Schedule,
  refDate: string = toDateKey(new Date()),
): CyclePreview {
  const cycle = getTherapyCycle(schedule)
  if (!cycle?.enabled || cycle.mode === 'continuous') {
    return {
      nextPauseStart: null,
      nextApplyStart: null,
      currently: 'continuous',
      label: 'Continuous — no cyclic pause',
    }
  }

  const anchor = resolveAnchor(schedule, cycle)
  const match = matchTherapyCycle(schedule, refDate)
  const currently = match?.phase ?? 'continuous'

  if (cycle.mode === 'on_off_days') {
    return previewOnOffDays(cycle, anchor, refDate, currently)
  }

  // week_slots: scan forward up to 2 years
  return previewByScan(schedule, refDate, currently)
}

function previewOnOffDays(
  cycle: TherapyCycle,
  anchor: string,
  refDate: string,
  currently: CyclePreview['currently'],
): CyclePreview {
  const onDays = Math.max(0, Math.floor(cycle.onDays || 0))
  const offDays = Math.max(0, Math.floor(cycle.offDays || 0))
  if (onDays <= 0 || offDays <= 0) {
    return {
      nextPauseStart: null,
      nextApplyStart: null,
      currently: onDays > 0 ? 'continuous' : 'pause',
      label: describeOnOff(onDays, offDays),
    }
  }

  const block = onDays + offDays
  const daysSince = differenceInCalendarDays(
    parseISO(toDateKey(refDate)),
    parseISO(toDateKey(anchor)),
  )

  let nextPauseStart: string | null = null
  let nextApplyStart: string | null = null

  if (daysSince < 0) {
    nextApplyStart = toDateKey(anchor)
    nextPauseStart = toDateKey(addDays(parseISO(anchor), onDays))
  } else {
    const pos = daysSince % block
    const blockStart = addDays(parseISO(toDateKey(refDate)), -pos)
    if (pos < onDays) {
      // in apply → pause starts at end of on phase
      nextPauseStart = toDateKey(addDays(blockStart, onDays))
      nextApplyStart = toDateKey(addDays(blockStart, block))
    } else {
      // in pause → apply starts at next block
      nextApplyStart = toDateKey(addDays(blockStart, block))
      nextPauseStart = toDateKey(addDays(blockStart, block + onDays))
    }
  }

  return {
    nextPauseStart,
    nextApplyStart,
    currently,
    label: describeOnOff(onDays, offDays),
  }
}

function previewByScan(
  schedule: Schedule,
  refDate: string,
  currently: CyclePreview['currently'],
): CyclePreview {
  const start = parseISO(toDateKey(refDate))
  let nextPauseStart: string | null = null
  let nextApplyStart: string | null = null
  const cur = matchTherapyCycle(schedule, refDate)

  for (let i = 0; i <= 400; i++) {
    const d = toDateKey(addDays(start, i))
    const m = matchTherapyCycle(schedule, d)
    if (!m) continue
    if (cur?.take && !m.take && !nextPauseStart) nextPauseStart = d
    if (cur && !cur.take && m.take && !nextApplyStart) nextApplyStart = d
    if (!cur?.take && m.take && !nextApplyStart && i > 0) nextApplyStart = d
    if (nextPauseStart && nextApplyStart) break
  }

  return {
    nextPauseStart,
    nextApplyStart,
    currently,
    label: describeTherapyCycle(schedule),
  }
}

function describeOnOff(onDays: number, offDays: number): string {
  if (offDays <= 0) return `Apply ${onDays} days`
  return `Apply ${onDays} days · pause ${offDays} days`
}

export function formatPreviewDate(dateKey: string | null): string {
  if (!dateKey) return '—'
  return format(parseISO(dateKey), 'd MMM yyyy')
}

export function normalizeTherapyCycle(
  partial: Partial<TherapyCycle> | null | undefined,
  fallbackAnchor: string,
): TherapyCycle | undefined {
  if (!partial?.enabled) return undefined
  const mode: TherapyCycleMode = partial.mode || 'on_off_days'
  if (mode === 'continuous') return undefined

  if (mode === 'week_slots') {
    const slots = (partial.slots ?? []).map((s) => ({
      take: Boolean(s.take),
      doseLabel: s.doseLabel?.trim() || undefined,
      name: s.name?.trim() || undefined,
    }))
    if (!slots.length) return undefined
    return {
      enabled: true,
      mode: 'week_slots',
      anchorDate: toDateKey(partial.anchorDate || fallbackAnchor),
      onDays: slots.filter((s) => s.take).length * 7,
      offDays: slots.filter((s) => !s.take).length * 7,
      slots,
    }
  }

  const onDays = Math.max(1, Math.floor(partial.onDays || 1))
  const offDays = Math.max(0, Math.floor(partial.offDays ?? 0))
  if (offDays === 0) return undefined

  return {
    enabled: true,
    mode: 'on_off_days',
    anchorDate: toDateKey(partial.anchorDate || fallbackAnchor),
    onDays,
    offDays,
  }
}

export function normalizeTimes(times: string[], fallback: string): string[] {
  const cleaned = times.map(normalizeTime).filter(Boolean)
  const unique = [...new Set(cleaned)]
  if (unique.length === 0) return [normalizeTime(fallback) || '08:00']
  return unique.sort()
}
