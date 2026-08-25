import {
  addDays,
  eachDayOfInterval,
  endOfMonth,
  endOfWeek,
  format,
  parseISO,
  startOfDay,
  startOfMonth,
  startOfWeek,
} from 'date-fns'

export function toDateKey(date: Date | string): string {
  const d = typeof date === 'string' ? parseISO(date) : date
  return format(startOfDay(d), 'yyyy-MM-dd')
}

export function parseDateKey(key: string): Date {
  return startOfDay(parseISO(key))
}

export function dayOfMonth(dateKey: string): number {
  return parseDateKey(dateKey).getDate()
}

export function startOfMonthKey(dateKey: string): string {
  return format(startOfMonth(parseDateKey(dateKey)), 'yyyy-MM-dd')
}

export function daysInMonth(dateKey: string): number {
  return endOfMonth(parseDateKey(dateKey)).getDate()
}

export function combineDateAndTime(dateKey: string, timeOfDay: string): string {
  const [hh = '08', mm = '00'] = timeOfDay.split(':')
  return `${dateKey}T${hh.padStart(2, '0')}:${mm.padStart(2, '0')}:00`
}

export function formatTime(timeOfDay: string): string {
  const [hh, mm] = timeOfDay.split(':').map(Number)
  const d = new Date()
  d.setHours(hh || 0, mm || 0, 0, 0)
  return format(d, 'h:mm a')
}

export function formatDisplayDate(dateKey: string): string {
  return format(parseDateKey(dateKey), 'EEE, MMM d')
}

export function formatLongDate(dateKey: string): string {
  return format(parseDateKey(dateKey), 'MMMM d, yyyy')
}

export function weekDays(anchor: Date): Date[] {
  const start = startOfWeek(anchor, { weekStartsOn: 0 })
  const end = endOfWeek(anchor, { weekStartsOn: 0 })
  return eachDayOfInterval({ start, end })
}

export function monthGridDays(anchor: Date): Date[] {
  const start = startOfWeek(startOfMonth(anchor), { weekStartsOn: 0 })
  const end = endOfWeek(endOfMonth(anchor), { weekStartsOn: 0 })
  return eachDayOfInterval({ start, end })
}

export function addDaysKey(dateKey: string, days: number): string {
  return toDateKey(addDays(parseDateKey(dateKey), days))
}

export function todayKey(): string {
  return toDateKey(new Date())
}
