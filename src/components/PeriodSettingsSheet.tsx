import { useEffect, useState, type FormEvent } from 'react'
import { Sheet } from './Sheet'
import { useCycleSettings, usePeriods } from '../hooks/useAppData'
import {
  deletePeriod,
  saveCycleSettings,
  upsertPeriod,
} from '../db/actions'
import { formatLongDate, todayKey } from '../lib/dates'
import {
  nextPredictedPeriodStart,
  periodLengthDays,
  sortPeriods,
} from '../lib/cycle'
import type { FlowNote, Period } from '../types'

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
      setMessage('Start date is required.')
      return
    }
    if (editing.endDate && editing.endDate < editing.startDate) {
      setMessage('End date cannot be before start date.')
      return
    }
    await upsertPeriod({
      id: editing.id,
      startDate: editing.startDate,
      endDate: editing.endDate || undefined,
      flowNote: editing.flowNote || undefined,
      notes: editing.notes || undefined,
    })
    setMessage(editing.id ? 'Period updated.' : 'Period added.')
    setEditing(null)
  }

  return (
    <Sheet open={open} title="Period settings" onClose={onClose}>
      <div className="space-y-4">
        <p className="text-sm text-ink-soft">
          Used for the cycle day strip and predicted period days. Next period
          (est.):{' '}
          <strong className="text-ink">
            {nextStart ? formatLongDate(nextStart) : '—'}
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
            setMessage('Settings saved.')
          }}
          className="grid gap-3 sm:grid-cols-2"
        >
          <label className="text-sm font-medium text-ink">
            Avg cycle length (days)
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
            Avg period length (days)
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
              Save settings
            </button>
          </div>
        </form>

        <div>
          <div className="mb-2 flex items-center justify-between gap-2">
            <p className="text-sm font-semibold text-ink">Period history</p>
            {!editing && (
              <button
                type="button"
                className="text-xs font-semibold text-blush-700"
                onClick={() => {
                  setMessage(null)
                  setEditing(emptyDraft())
                }}
              >
                + Add period
              </button>
            )}
          </div>

          {editing && (
            <form
              onSubmit={savePeriod}
              className="mb-3 space-y-3 rounded-2xl bg-white p-3 ring-1 ring-blush-100"
            >
              <p className="text-xs font-semibold uppercase tracking-wide text-ink-muted">
                {editing.id ? 'Edit period' : 'New period'}
              </p>
              <div className="grid gap-3 sm:grid-cols-2">
                <label className="text-sm font-medium text-ink">
                  Start date
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
                  End date
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
                    Leave empty if still ongoing
                  </span>
                </label>
                <label className="text-sm font-medium text-ink sm:col-span-2">
                  Flow
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
                    <option value="">—</option>
                    <option value="spotting">Spotting</option>
                    <option value="light">Light</option>
                    <option value="medium">Medium</option>
                    <option value="heavy">Heavy</option>
                  </select>
                </label>
                <label className="text-sm font-medium text-ink sm:col-span-2">
                  Notes
                  <input
                    type="text"
                    value={editing.notes}
                    onChange={(e) =>
                      setEditing((d) =>
                        d ? { ...d, notes: e.target.value } : d,
                      )
                    }
                    placeholder="Optional"
                    className="soft-input mt-1"
                  />
                </label>
              </div>
              <div className="flex flex-wrap gap-2">
                <button type="submit" className="btn-primary !px-3 !py-1.5 text-xs">
                  {editing.id ? 'Save changes' : 'Add period'}
                </button>
                <button
                  type="button"
                  className="btn-ghost !px-3 !py-1.5 text-xs"
                  onClick={() => setEditing(null)}
                >
                  Cancel
                </button>
              </div>
            </form>
          )}

          {sorted.length === 0 && !editing ? (
            <p className="text-sm text-ink-muted">No periods logged yet.</p>
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
                        {formatLongDate(p.startDate)}
                        {p.endDate
                          ? ` → ${formatLongDate(p.endDate)}`
                          : ' → …'}
                        <span className="block text-xs text-ink-muted">
                          ~{periodLengthDays(p, settings.averagePeriodLength)}{' '}
                          days
                          {p.flowNote ? ` · ${p.flowNote}` : ''}
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
                          Edit
                        </button>
                        <button
                          type="button"
                          className="text-xs font-semibold text-rose-600"
                          onClick={() => {
                            if (confirm('Delete this period?')) {
                              void deletePeriod(p.id)
                              if (editing?.id === p.id) setEditing(null)
                            }
                          }}
                        >
                          Delete
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
