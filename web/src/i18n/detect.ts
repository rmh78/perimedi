import type { Locale } from './types'

export const LOCALE_STORAGE_KEY = 'perimedi.locale'

export function isLocale(value: unknown): value is Locale {
  return value === 'en' || value === 'de'
}

/** Browser default: German if preferred languages include `de`, else English. */
export function detectBrowserLocale(): Locale {
  if (typeof navigator === 'undefined') return 'en'
  const list =
    navigator.languages?.length > 0
      ? navigator.languages
      : [navigator.language]
  for (const lang of list) {
    if (lang.toLowerCase().startsWith('de')) return 'de'
  }
  return 'en'
}

export function readStoredLocale(): Locale | null {
  try {
    const raw = localStorage.getItem(LOCALE_STORAGE_KEY)
    return isLocale(raw) ? raw : null
  } catch {
    return null
  }
}

export function resolveInitialLocale(): Locale {
  return readStoredLocale() ?? detectBrowserLocale()
}

export function writeStoredLocale(locale: Locale): void {
  try {
    localStorage.setItem(LOCALE_STORAGE_KEY, locale)
  } catch {
    /* ignore quota / private mode */
  }
}

export function applyDocumentLang(locale: Locale): void {
  if (typeof document !== 'undefined') {
    document.documentElement.lang = locale
  }
}
