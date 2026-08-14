import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import {
  applyDocumentLang,
  resolveInitialLocale,
  writeStoredLocale,
} from './detect'
import { de } from './messages/de'
import { en, type MessageKey } from './messages/en'
import { translate } from './t'
import type { Locale, MessageParams } from './types'
import { formatLocalized, getDateFnsLocale } from './format'

const catalogs = { en, de } as const

type TFunction = (key: MessageKey, params?: MessageParams) => string

type LocaleContextValue = {
  locale: Locale
  setLocale: (locale: Locale) => void
  t: TFunction
  formatDate: (date: Date | string, pattern: string) => string
  dateFnsLocale: ReturnType<typeof getDateFnsLocale>
}

const LocaleContext = createContext<LocaleContextValue | null>(null)

const initial = resolveInitialLocale()
applyDocumentLang(initial)

export function LocaleProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>(initial)

  const setLocale = useCallback((next: Locale) => {
    setLocaleState(next)
    writeStoredLocale(next)
    applyDocumentLang(next)
  }, [])

  const t = useCallback<TFunction>(
    (key, params) => translate(catalogs[locale], key, params),
    [locale],
  )

  const formatDate = useCallback(
    (date: Date | string, pattern: string) =>
      formatLocalized(date, pattern, locale),
    [locale],
  )

  const value = useMemo<LocaleContextValue>(
    () => ({
      locale,
      setLocale,
      t,
      formatDate,
      dateFnsLocale: getDateFnsLocale(locale),
    }),
    [locale, setLocale, t, formatDate],
  )

  return (
    <LocaleContext.Provider value={value}>{children}</LocaleContext.Provider>
  )
}

export function useLocale(): LocaleContextValue {
  const ctx = useContext(LocaleContext)
  if (!ctx) {
    throw new Error('useLocale must be used within LocaleProvider')
  }
  return ctx
}

export function useT(): TFunction {
  return useLocale().t
}
