import { useEffect, useState, type FormEvent } from 'react'
import { Sheet } from './Sheet'
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
import type { FlowNote, Period } from '../types'
import { useLocale, formatLocalized, formatLongDateLocalized, type Locale } from '../i18n'
import { useConfirm } from '../context/ConfirmContext'
import { HistoryIconButton } from './HistoryIconButton'

type Props = {
  open: boolean
  onClose: () => void
}

type PeriodDraft = {
  id?: string
  startDate: string
  endDate: string
  flowNote: FlowNote | ''
  notes: string
}

const emptyDraft = (): PeriodDraft => ({
  startDate: todayKey(),
  endDate: '',
  flowNote: 'medium',
  notes: '',
})

function draftFromPeriod(p: Period): PeriodDraft {
  return {
    id: p.id,
    startDate: p.startDate,
    endDate: p.endDate ?? '',
    flowNote: p.flowNote ?? '',
    notes: p.notes ?? '',
  }
}

function compactRange(startKey: string, endKey: string | undefined, locale: Locale): string {
  const start = formatLocalized(startKey, 'd MMM yyyy', locale)
  if (!endKey) return `${start} → …`
  const [sy, sm] = startKey.split('-')
  const [ey, em] = endKey.split('-')
  if (sy === ey && sm === em) {
    return `${formatLocalized(startKey, 'd', locale)}–${formatLocalized(endKey, 'd', locale)} ${formatLocalized(endKey, 'MMM yyyy', locale)}`
  }
  if (sy === ey) {
    return `${formatLocalized(startKey, 'd MMM', locale)} – ${formatLocalized(endKey, 'd MMM yyyy', locale)}`
  }
  return `${start} – ${formatLocalized(endKey, 'd MMM yyyy', locale)}`
}

export function PeriodSettingsSheet({ open, onClose }: Props) {
  const { t, locale } = useLocale()
  const confirm = useConfirm()
  const settings = useCycleSettings()
  const periods = usePeriods()
  const sorted = sortPeriods(periods)
  const nextStart = nextPredictedPeriodStart(periods, settings)
  const [message, setMessage] = useState<string | null>(null)
  const [editing, setEditing] = useState<PeriodDraft | null>(null)

  useEffect(() => {
    if (!open) {
      setEditing(null)
      setMessage(null)
    }
  }, [open])

  async function savePeriod(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    if (!editing) return
    if (!editing.startDate) {
      setMessage(t('period.startRequired'))
      return
    }
    if (editing.endDate && editing.endDate < editing.startDate) {
      setMessage(t('period.endBeforeStart'))
      return
    }
    await upsertPeriod({
      id: editing.id,
      startDate: editing.startDate,
      endDate: editing.endDate || undefined,
      flowNote: editing.flowNote || undefined,
      notes: editing.notes || undefined,
    })
    setMessage(editing.id ? t('period.updated') : t('period.added'))
    setEditing(null)
  }

  function flowLabel(note: FlowNote | undefined): string {
    if (!note) return ''
    return t(`flow.${note}` as 'flow.medium')
  }

  return (
    <Sheet
      open={open}
      title={t('period.title')}
      icon="/action-icons/period.jpg"
      onClose={() => {
        void saveCycleSettings({
          averageCycleLength: settings.averageCycleLength,
          averagePeriodLength: settings.averagePeriodLength,
          tracksPeriods: settings.tracksPeriods,
        })
        onClose()
      }}
    >
      <div className="space-y-4">
        <label className="flex items-center justify-between gap-3 text-sm font-semibold text-ink">
          {t('period.track')}
          <input
            type="checkbox"
            className="h-5 w-5 accent-blush-600"
            checked={settings.tracksPeriods !== false}
            onChange={(e) => {
              void saveCycleSettings({ tracksPeriods: e.target.checked })
            }}
          />
        </label>

        {settings.tracksPeriods === false ? (
          <p className="text-sm text-ink-soft">{t('period.trackOffHint')}</p>
        ) : (
          <>
        <p className="text-sm text-ink-soft">
          {t('period.intro')}{' '}
          <strong className="text-ink">
            {nextStart
              ? formatLongDateLocalized(nextStart, locale)
              : t('common.emDash')}
          </strong>
        </p>

        {message && (
          <p className="rounded-xl bg-emerald-50 px-3 py-2 text-sm text-emerald-900">
            {message}
          </p>
        )}

        <div className="grid grid-cols-2 gap-3">
          <label className="text-sm font-medium text-ink">
            {t('period.avgCycle')}
            <select
              className="soft-input mt-1"
              value={settings.averageCycleLength}
              onChange={(e) => {
                void saveCycleSettings({
                  averageCycleLength: Number(e.target.value) || 28,
                })
              }}
            >
              {Array.from({ length: 31 }, (_, i) => i + 15).map((n) => (
                <option key={n} value={n}>
                  {n}
                </option>
              ))}
            </select>
          </label>
          <label className="text-sm font-medium text-ink">
            {t('period.avgPeriod')}
            <select
              className="soft-input mt-1"
              value={settings.averagePeriodLength}
              onChange={(e) => {
                void saveCycleSettings({
                  averagePeriodLength: Number(e.target.value) || 5,
                })
              }}
            >
              {Array.from({ length: 15 }, (_, i) => i + 1).map((n) => (
                <option key={n} value={n}>
                  {n}
                </option>
              ))}
            </select>
          </label>
        </div>

        {!editing && (
          <button
            type="button"
            className="btn-ghost !min-h-9 !px-3"
            onClick={() => {
              setMessage(null)
              setEditing(emptyDraft())
            }}
          >
            {t('period.add')}
          </button>
        )}

        {editing && (
          <form
            onSubmit={savePeriod}
            className="space-y-3 rounded-2xl bg-white p-3 ring-1 ring-blush-100"
          >
              <p className="text-xs font-semibold uppercase tracking-wide text-ink-muted">
                {editing.id ? t('period.edit') : t('period.new')}
              </p>
              <div className="grid grid-cols-2 gap-3">
                <label className="text-sm font-medium text-ink">
                  {t('period.startDate')}
                  <input
                    type="date"
                    required
                    value={editing.startDate}
                    onChange={(e) =>
                      setEditing((d) =>
                        d ? { ...d, startDate: e.target.value } : d,
                      )
                    }
                    className="soft-input mt-1"
                  />
                </label>
                <label className="text-sm font-medium text-ink">
                  {t('period.endDate')}
                  <input
                    type="date"
                    value={editing.endDate}
                    min={editing.startDate || undefined}
                    onChange={(e) =>
                      setEditing((d) =>
                        d ? { ...d, endDate: e.target.value } : d,
                      )
                    }
                    className="soft-input mt-1"
                  />
                  <span className="mt-0.5 block text-[10px] font-normal text-ink-muted">
                    {t('period.endHint')}
                  </span>
                </label>
                <label className="text-sm font-medium text-ink col-span-2">
                  {t('period.flow')}
                  <select
                    value={editing.flowNote}
                    onChange={(e) =>
                      setEditing((d) =>
                        d
                          ? {
                              ...d,
                              flowNote: e.target.value as FlowNote | '',
                            }
                          : d,
                      )
                    }
                    className="soft-input mt-1"
                  >
                    <option value="">{t('common.emDash')}</option>
                    <option value="spotting">{t('flow.spotting')}</option>
                    <option value="light">{t('flow.light')}</option>
                    <option value="medium">{t('flow.medium')}</option>
                    <option value="heavy">{t('flow.heavy')}</option>
                  </select>
                </label>
              </div>
              <div className="flex flex-wrap gap-2">
                <button type="submit" className="btn-primary !px-3 !py-1.5 text-xs">
                  {editing.id ? t('period.saveChanges') : t('period.addPeriod')}
                </button>
                <button
                  type="button"
                  className="btn-ghost !px-3 !py-1.5 text-xs"
                  onClick={() => setEditing(null)}
                >
                  {t('common.cancel')}
                </button>
              </div>
            </form>
          )}

        <div>
          <p className="mb-2 text-sm font-semibold text-ink">{t('period.history')}</p>

          {sorted.length === 0 ? (
            <p className="text-sm text-ink-muted">{t('period.none')}</p>
          ) : (
            <ul className="divide-y divide-blush-100">
              {sorted.map((p) => {
                const isActive = editing?.id === p.id
                return (
                  <li
                    key={p.id}
                    className={`flex items-center gap-2 py-2 text-sm ${
                      isActive ? 'bg-blush-50/80' : ''
                    }`}
                  >
                      <span className="min-w-0 flex-1">
                        <span className="block truncate font-semibold text-ink">
                          {compactRange(p.startDate, p.endDate, locale)}
                        </span>
                        <span className="block truncate text-xs text-ink-muted">
                          {t('period.daysApprox', {
                            days: periodLengthDays(
                              p,
                              settings.averagePeriodLength,
                            ),
                          })}
                          {p.flowNote ? ` · ${flowLabel(p.flowNote)}` : ''}
                          {p.notes ? ` · ${p.notes}` : ''}
                        </span>
                      </span>
                      <div className="flex shrink-0 gap-1">
                        <HistoryIconButton
                          kind="edit"
                          label={t('common.edit')}
                          onClick={() => {
                            setMessage(null)
                            setEditing(draftFromPeriod(p))
                          }}
                        />
                        <HistoryIconButton
                          kind="delete"
                          label={t('common.delete')}
                          onClick={() => {
                            void confirm({
                              message: t('period.deleteConfirm'),
                              danger: true,
                            }).then((ok) => {
                              if (!ok) return
                              void deletePeriod(p.id)
                              if (editing?.id === p.id) setEditing(null)
                            })
                          }}
                        />
                      </div>
                  </li>
                )
              })}
            </ul>
          )}
        </div>
          </>
        )}
      </div>
    </Sheet>
  )
}
