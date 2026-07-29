import { useRef, useState, type FormEvent } from 'react'
import { Sheet } from './Sheet'
import {
  clearAllData,
  loadSampleData,
} from '../lib/seed'
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
import { formatLongDate, todayKey } from '../lib/dates'
import {
  nextPredictedPeriodStart,
  periodLengthDays,
  sortPeriods,
} from '../lib/cycle'

type Props = {
  open: boolean
  onClose: () => void
}

export function MoreSheet({ open, onClose }: Props) {
  const [tab, setTab] = useState<'data' | 'cycle'>('data')
  const fileRef = useRef<HTMLInputElement>(null)
  const [message, setMessage] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  const settings = useCycleSettings()
  const periods = usePeriods()
  const sorted = sortPeriods(periods)
  const nextStart = nextPredictedPeriodStart(periods, settings)

  return (
    <Sheet open={open} title="More" onClose={onClose} wide>
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
          Backup
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
          Period settings
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
            title="Sample data"
            body="Fictional perimenopause demo (HRT-style plan, irregular cycles, symptoms)."
            label="Load sample"
            onClick={async () => {
              if (
                confirm(
                  'Replace all local data with the perimenopause sample set?',
                )
              ) {
                await loadSampleData()
                setMessage('Perimenopause sample data loaded.')
                setError(null)
              }
            }}
          />
          <Action
            title="Export"
            body="Download JSON backup."
            label="Export"
            onClick={async () => {
              try {
                downloadJson(await exportAllData())
                setMessage('Backup downloaded.')
                setError(null)
              } catch (e) {
                setError(e instanceof Error ? e.message : 'Export failed')
              }
            }}
          />
          <Action
            title="Import"
            body="Restore from a backup file."
            label="Choose file"
            onClick={() => fileRef.current?.click()}
          />
          <Action
            title="Clear"
            body="Wipe everything on this device."
            label="Clear all"
            danger
            onClick={async () => {
              if (confirm('Delete all PeriMedi data on this device?')) {
                await clearAllData()
                setMessage('Cleared.')
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
                setMessage('Import complete.')
                setError(null)
              } catch (err) {
                setError(err instanceof Error ? err.message : 'Import failed')
              }
              e.target.value = ''
            }}
          />
        </div>
      )}

      {tab === 'cycle' && (
        <div className="space-y-4">
          <p className="text-sm text-ink-soft">
            Next period (est.):{' '}
            <strong>{nextStart ? formatLongDate(nextStart) : '—'}</strong>
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
              setMessage('Cycle settings saved.')
            }}
            className="grid gap-3 sm:grid-cols-2"
          >
            <label className="text-sm">
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
            <label className="text-sm">
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
            <p className="mb-2 text-sm font-semibold">Period history</p>
            <p className="mb-2 text-xs text-ink-muted">
              Tap Edit to change start/end dates. Open Period settings from the
              cycle day strip for full editing.
            </p>
            {sorted.length === 0 ? (
              <p className="text-sm text-ink-muted">No periods logged.</p>
            ) : (
              <ul className="space-y-2">
                {sorted.map((p) => (
                  <li
                    key={p.id}
                    className="flex flex-wrap items-center justify-between gap-2 rounded-xl bg-blush-50/80 px-3 py-2 text-sm"
                  >
                    <span>
                      {formatLongDate(p.startDate)}
                      {p.endDate ? ` → ${formatLongDate(p.endDate)}` : ' → …'}
                      <span className="block text-xs text-ink-muted">
                        ~{periodLengthDays(p, settings.averagePeriodLength)} days
                      </span>
                    </span>
                    <div className="flex gap-2">
                      <button
                        type="button"
                        className="text-xs font-semibold text-blush-700"
                        onClick={async () => {
                          const start = window.prompt(
                            'Start date (YYYY-MM-DD)',
                            p.startDate,
                          )
                          if (!start) return
                          const end = window.prompt(
                            'End date (YYYY-MM-DD), empty if ongoing',
                            p.endDate ?? '',
                          )
                          if (end === null) return
                          if (end && end < start) {
                            setError('End date cannot be before start.')
                            return
                          }
                          await upsertPeriod({
                            id: p.id,
                            startDate: start,
                            endDate: end || undefined,
                            flowNote: p.flowNote,
                            notes: p.notes,
                          })
                          setMessage('Period updated.')
                          setError(null)
                        }}
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        className="text-xs font-semibold text-rose-600"
                        onClick={() => {
                          if (confirm('Delete this period?'))
                            void deletePeriod(p.id)
                        }}
                      >
                        Delete
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
                  'Period start date (YYYY-MM-DD)',
                  todayKey(),
                )
                if (!start) return
                await upsertPeriod({ startDate: start, flowNote: 'medium' })
                setMessage('Period added.')
              }}
            >
              + Log period (date)
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
