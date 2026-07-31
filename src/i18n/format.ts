import { format, parseISO, type Locale as DateFnsLocale } from 'date-fns'
import { de } from 'date-fns/locale/de'
import { enUS } from 'date-fns/locale/en-US'
import type { Locale } from './types'

export function getDateFnsLocale(locale: Locale): DateFnsLocale {
  return locale === 'de' ? de : enUS
}

export function formatLocalized(
  date: Date | string,
  pattern: string,
  locale: Locale,
): string {
  const d = typeof date === 'string' ? parseISO(date) : date
  return format(d, pattern, { locale: getDateFnsLocale(locale) })
}

export function formatLongDateLocalized(
  dateKey: string,
  locale: Locale,
): string {
  return formatLocalized(dateKey, 'PPP', locale)
}

export function formatDisplayDateLocalized(
  dateKey: string,
  locale: Locale,
): string {
  return formatLocalized(dateKey, 'EEE, d MMM', locale)
}
