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
import { useLocale, formatLongDateLocalized } from '../i18n'

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

export function PeriodSettingsSheet({ open, onClose }: Props) {
  const { t, locale } = useLocale()
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
    <Sheet open={open} title={t('period.title')} onClose={onClose}>
      <div className="space-y-4">
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

        <form
          key={`${settings.averageCycleLength}-${settings.averagePeriodLength}`}
          onSubmit={async (e: FormEvent<HTMLFormElement>) => {
            e.preventDefault()
            const fd = new FormData(e.currentTarget)
            await saveCycleSettings({
              averageCycleLength: Number(fd.get('cycleLen')) || 28,
              averagePeriodLength: Number(fd.get('periodLen')) || 5,
            })
            setMessage(t('period.settingsSaved'))
          }}
          className="grid gap-3 sm:grid-cols-2"
        >
          <label className="text-sm font-medium text-ink">
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
          <label className="text-sm font-medium text-ink">
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
          <div className="mb-2 flex items-center justify-between gap-2">
            <p className="text-sm font-semibold text-ink">{t('period.history')}</p>
            {!editing && (
              <button
                type="button"
                className="text-xs font-semibold text-blush-700"
                onClick={() => {
                  setMessage(null)
                  setEditing(emptyDraft())
                }}
              >
                {t('period.add')}
              </button>
            )}
          </div>

          {editing && (
            <form
              onSubmit={savePeriod}
              className="mb-3 space-y-3 rounded-2xl bg-white p-3 ring-1 ring-blush-100"
            >
              <p className="text-xs font-semibold uppercase tracking-wide text-ink-muted">
                {editing.id ? t('period.edit') : t('period.new')}
              </p>
              <div className="grid gap-3 sm:grid-cols-2">
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
                <label className="text-sm font-medium text-ink sm:col-span-2">
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
                <label className="text-sm font-medium text-ink sm:col-span-2">
                  {t('period.notes')}
                  <input
                    type="text"
                    value={editing.notes}
                    onChange={(e) =>
                      setEditing((d) =>
                        d ? { ...d, notes: e.target.value } : d,
                      )
                    }
                    placeholder={t('common.optional')}
                    className="soft-input mt-1"
                  />
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

          {sorted.length === 0 && !editing ? (
            <p className="text-sm text-ink-muted">{t('period.none')}</p>
          ) : (
            <ul className="space-y-2">
              {sorted.map((p) => {
                const isActive = editing?.id === p.id
                return (
                  <li
                    key={p.id}
                    className={`rounded-xl px-3 py-2 text-sm ${
                      isActive
                        ? 'bg-blush-100 ring-1 ring-blush-200'
                        : 'bg-blush-50/80'
                    }`}
                  >
                    <div className="flex flex-wrap items-start justify-between gap-2">
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
                          {p.flowNote ? ` · ${flowLabel(p.flowNote)}` : ''}
                          {p.notes ? ` · ${p.notes}` : ''}
                        </span>
                      </span>
                      <div className="flex shrink-0 gap-2">
                        <button
                          type="button"
                          className="text-xs font-semibold text-blush-700"
                          onClick={() => {
                            setMessage(null)
                            setEditing(draftFromPeriod(p))
                          }}
                        >
                          {t('common.edit')}
                        </button>
                        <button
                          type="button"
                          className="text-xs font-semibold text-rose-600"
                          onClick={() => {
                            if (confirm(t('period.deleteConfirm'))) {
                              void deletePeriod(p.id)
                              if (editing?.id === p.id) setEditing(null)
                            }
                          }}
                        >
                          {t('common.delete')}
                        </button>
                      </div>
                    </div>
                  </li>
                )
              })}
            </ul>
          )}
        </div>
      </div>
    </Sheet>
  )
}
