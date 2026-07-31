import { useRef, useState, type FormEvent } from 'react'
import { Sheet } from './Sheet'
import { clearAllData, loadSampleData } from '../lib/seed'
import {
  downloadJson,
  exportAllData,
  importAllData,
} from '../lib/backup'
import type { ExportPayload } from '../types'
import { useCycleSettings, usePeriods } from '../hooks/useAppData'
import {
  deletePeriod,
  saveCycleSettings,
  upsertPeriod,
} from '../db/actions'
import { todayKey } from '../lib/dates'
import {
  nextPredictedPeriodStart,
  periodLengthDays,
  sortPeriods,
} from '../lib/cycle'
import { useLocale, formatLongDateLocalized, type Locale } from '../i18n'

type Props = {
  open: boolean
  onClose: () => void
}

export function MoreSheet({ open, onClose }: Props) {
  const { t, locale, setLocale } = useLocale()
  const [tab, setTab] = useState<'data' | 'cycle'>('data')
  const fileRef = useRef<HTMLInputElement>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  const settings = useCycleSettings()
  const periods = usePeriods()
  const sorted = sortPeriods(periods)
  const nextStart = nextPredictedPeriodStart(periods, settings)

  return (
    <Sheet open={open} title={t('more.title')} onClose={onClose} wide>
      <div className="mb-4">
        <p className="mb-1.5 text-xs font-semibold uppercase tracking-wide text-ink-muted">
          {t('language.label')}
        </p>
        <div className="flex gap-2">
          {(['en', 'de'] as const).map((code) => (
            <button
              key={code}
              type="button"
              className={`rounded-full px-3 py-1.5 text-xs font-semibold ${
                locale === code
                  ? 'bg-blush-600 text-white'
                  : 'bg-blush-50 text-blush-800'
              }`}
              onClick={() => setLocale(code as Locale)}
              aria-pressed={locale === code}
            >
              {t(code === 'en' ? 'language.en' : 'language.de')}
            </button>
          ))}
        </div>
      </div>

      <div className="mb-4 flex gap-2">
        <button
          type="button"
          className={`rounded-full px-3 py-1.5 text-xs font-semibold ${
            tab === 'data'
              ? 'bg-blush-600 text-white'
              : 'bg-blush-50 text-blush-800'
          }`}
          onClick={() => setTab('data')}
        >
          {t('more.tabBackup')}
        </button>
        <button
          type="button"
          className={`rounded-full px-3 py-1.5 text-xs font-semibold ${
            tab === 'cycle'
              ? 'bg-blush-600 text-white'
              : 'bg-blush-50 text-blush-800'
          }`}
          onClick={() => setTab('cycle')}
        >
          {t('more.tabPeriod')}
        </button>
      </div>

      {(message || error) && (
        <div
          className={`mb-3 rounded-xl px-3 py-2 text-sm ${
            error
              ? 'bg-rose-50 text-rose-900'
              : 'bg-emerald-50 text-emerald-900'
          }`}
        >
          {error ?? message}
        </div>
      )}

      {tab === 'data' && (
        <div className="grid gap-3 sm:grid-cols-2">
          <Action
            title={t('more.sampleTitle')}
            body={t('more.sampleBody')}
            label={t('more.sampleLabel')}
            onClick={async () => {
              if (confirm(t('more.sampleConfirm'))) {
                await loadSampleData()
                setMessage(t('more.sampleLoaded'))
                setError(null)
              }
            }}
          />
          <Action
            title={t('more.exportTitle')}
            body={t('more.exportBody')}
            label={t('more.exportLabel')}
            onClick={async () => {
              try {
                downloadJson(await exportAllData())
                setMessage(t('more.exportDone'))
                setError(null)
              } catch (e) {
                setError(
                  e instanceof Error ? e.message : t('more.exportFailed'),
                )
              }
            }}
          />
          <Action
            title={t('more.importTitle')}
            body={t('more.importBody')}
            label={t('more.importLabel')}
            onClick={() => fileRef.current?.click()}
          />
          <Action
            title={t('more.clearTitle')}
            body={t('more.clearBody')}
            label={t('more.clearLabel')}
            danger
            onClick={async () => {
              if (confirm(t('more.clearConfirm'))) {
                await clearAllData()
                setMessage(t('more.cleared'))
                setError(null)
              }
            }}
          />
          <input
            ref={fileRef}
            type="file"
            accept="application/json,.json"
            className="hidden"
            onChange={async (e) => {
              const file = e.target.files?.[0]
              if (!file) return
              try {
                const payload = JSON.parse(await file.text()) as ExportPayload
                await importAllData(payload)
                setMessage(t('more.importDone'))
                setError(null)
              } catch (err) {
                setError(
                  err instanceof Error ? err.message : t('more.importFailed'),
                )
              }
              e.target.value = ''
            }}
          />
        </div>
      )}

      {tab === 'cycle' && (
        <div className="space-y-4">
          <p className="text-sm text-ink-soft">
            {t('more.nextPeriod')}{' '}
            <strong>
              {nextStart
                ? formatLongDateLocalized(nextStart, locale)
                : t('common.emDash')}
            </strong>
          </p>
          <form
            key={`${settings.averageCycleLength}-${settings.averagePeriodLength}`}
            onSubmit={async (e: FormEvent<HTMLFormElement>) => {
              e.preventDefault()
              const fd = new FormData(e.currentTarget)
              await saveCycleSettings({
                averageCycleLength: Number(fd.get('cycleLen')) || 28,
                averagePeriodLength: Number(fd.get('periodLen')) || 5,
              })
              setMessage(t('more.cycleSaved'))
            }}
            className="grid gap-3 sm:grid-cols-2"
          >
            <label className="text-sm">
              {t('period.avgCycle')}
              <input
                name="cycleLen"
                type="number"
                min={15}
                max={60}
                defaultValue={settings.averageCycleLength}
                className="soft-input mt-1"
              />
            </label>
            <label className="text-sm">
              {t('period.avgPeriod')}
              <input
                name="periodLen"
                type="number"
                min={1}
                max={15}
                defaultValue={settings.averagePeriodLength}
                className="soft-input mt-1"
              />
            </label>
            <div className="sm:col-span-2">
              <button type="submit" className="btn-primary">
                {t('period.saveSettings')}
              </button>
            </div>
          </form>

          <div>
            <p className="mb-2 text-sm font-semibold">{t('period.history')}</p>
            <p className="mb-2 text-xs text-ink-muted">{t('more.historyHint')}</p>
            {sorted.length === 0 ? (
              <p className="text-sm text-ink-muted">{t('more.noPeriods')}</p>
            ) : (
              <ul className="space-y-2">
                {sorted.map((p) => (
                  <li
                    key={p.id}
                    className="flex flex-wrap items-center justify-between gap-2 rounded-xl bg-blush-50/80 px-3 py-2 text-sm"
                  >
                    <span>
                      {formatLongDateLocalized(p.startDate, locale)}
                      {p.endDate
                        ? ` → ${formatLongDateLocalized(p.endDate, locale)}`
                        : ' → …'}
                      <span className="block text-xs text-ink-muted">
                        {t('period.daysApprox', {
                          days: periodLengthDays(
                            p,
                            settings.averagePeriodLength,
                          ),
                        })}
                      </span>
                    </span>
                    <div className="flex gap-2">
                      <button
                        type="button"
                        className="text-xs font-semibold text-blush-700"
                        onClick={async () => {
                          const start = window.prompt(
                            t('more.promptStart'),
                            p.startDate,
                          )
                          if (!start) return
                          const end = window.prompt(
                            t('more.promptEnd'),
                            p.endDate ?? '',
                          )
                          if (end === null) return
                          if (end && end < start) {
                            setError(t('more.endBeforeStart'))
                            return
                          }
                          await upsertPeriod({
                            id: p.id,
                            startDate: start,
                            endDate: end || undefined,
                            flowNote: p.flowNote,
                            notes: p.notes,
                          })
                          setMessage(t('period.updated'))
                          setError(null)
                        }}
                      >
                        {t('common.edit')}
                      </button>
                      <button
                        type="button"
                        className="text-xs font-semibold text-rose-600"
                        onClick={() => {
                          if (confirm(t('period.deleteConfirm')))
                            void deletePeriod(p.id)
                        }}
                      >
                        {t('common.delete')}
                      </button>
                    </div>
                  </li>
                ))}
              </ul>
            )}
            <button
              type="button"
              className="mt-3 text-sm font-semibold text-blush-700"
              onClick={async () => {
                const start = window.prompt(
                  t('more.promptPeriodStart'),
                  todayKey(),
                )
                if (!start) return
                await upsertPeriod({ startDate: start, flowNote: 'medium' })
                setMessage(t('period.added'))
              }}
            >
              {t('more.logPeriodDate')}
            </button>
          </div>
        </div>
      )}
    </Sheet>
  )
}

function Action({
  title,
  body,
  label,
  onClick,
  danger,
}: {
  title: string
  body: string
  label: string
  onClick: () => void | Promise<void>
  danger?: boolean
}) {
  return (
    <div className="rounded-2xl bg-blush-50/60 p-3 ring-1 ring-blush-100">
      <p className="font-semibold text-ink">{title}</p>
      <p className="mt-0.5 text-xs text-ink-soft">{body}</p>
      <button
        type="button"
        onClick={() => void onClick()}
        className={`mt-2 ${danger ? 'btn-soft' : 'btn-primary'} !py-1.5 text-xs`}
      >
        {label}
      </button>
    </div>
  )
}
