import type { PlannedDose } from '../types'
import { MED_FORM_LABELS } from '../types'
import { formatTime } from '../lib/dates'
import { setDoseStatus } from '../db/actions'

const statusStyles: Record<string, string> = {
  pending: 'border-blush-100 bg-white/90',
  taken: 'border-emerald-100 bg-emerald-50/80',
  skipped: 'border-amber-100 bg-amber-50/80',
}

const statusLabels: Record<string, string> = {
  pending: 'Open',
  taken: 'Taken',
  skipped: 'Skipped',
}

export function DoseCard({
  dose,
  compact = false,
}: {
  dose: PlannedDose
  compact?: boolean
}) {
  async function mark(status: 'taken' | 'skipped' | 'pending') {
    let skipReason: string | undefined
    if (status === 'skipped' && dose.status !== 'skipped') {
      skipReason =
        window.prompt('Optional reason for skipping:') || undefined
    }
    await setDoseStatus({
      medicationId: dose.medication.id,
      scheduleId: dose.schedule.id,
      date: dose.date,
      timeOfDay: dose.timeOfDay,
      status,
      skipReason,
      existingLogId: dose.log?.id,
    })
  }

  return (
    <article
      className={`rounded-2xl border p-4 shadow-[0_8px_24px_-18px_rgba(148,39,75,0.35)] ${statusStyles[dose.status]}`}
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="font-semibold text-ink">{dose.medication.name}</p>
          <p className="mt-0.5 text-sm text-ink-soft">
            {formatTime(dose.timeOfDay)} · {dose.doseLabel} ·{' '}
            {MED_FORM_LABELS[dose.medication.form]}
          </p>
          {!compact && dose.medication.instructions && (
            <p className="mt-1 text-sm text-ink-muted">
              {dose.medication.instructions}
            </p>
          )}
          {(dose.schedule.cycleRule !== 'none' ||
            dose.schedule.therapyCycle?.enabled ||
            dose.schedule.weekPattern?.enabled) && (
            <p className="mt-1 text-xs font-medium text-lilac-700">
              {dose.schedule.cycleRule !== 'none' && (
                <span>
                  Cycle-aware · {dose.schedule.cycleRule.replaceAll('_', ' ')}
                </span>
              )}
              {dose.schedule.cycleRule !== 'none' &&
                (dose.schedule.therapyCycle?.enabled ||
                  dose.schedule.weekPattern?.enabled) &&
                ' · '}
              {(dose.schedule.therapyCycle?.enabled ||
                dose.schedule.weekPattern?.enabled) && (
                <span>On/off cycle</span>
              )}
            </p>
          )}
          {dose.log?.skipReason && (
            <p className="mt-1 text-xs text-amber-800">
              Skipped: {dose.log.skipReason}
            </p>
          )}
        </div>
        <StatusPill status={dose.status} />
      </div>
      <div className="mt-3 flex flex-wrap gap-2">
        <StatusButton
          active={dose.status === 'taken'}
          tone="taken"
          onClick={() => mark('taken')}
        >
          Taken
        </StatusButton>
        <StatusButton
          active={dose.status === 'skipped'}
          tone="skipped"
          onClick={() => mark('skipped')}
        >
          Skipped
        </StatusButton>
        <StatusButton
          active={dose.status === 'pending'}
          tone="open"
          onClick={() => mark('pending')}
        >
          Open
        </StatusButton>
      </div>
    </article>
  )
}

function StatusPill({ status }: { status: string }) {
  const map: Record<string, string> = {
    pending: 'bg-blush-50 text-ink-soft ring-1 ring-blush-100',
    taken: 'bg-emerald-100 text-emerald-900 ring-1 ring-emerald-200',
    skipped: 'bg-amber-100 text-amber-900 ring-1 ring-amber-200',
  }
  return (
    <span
      className={`rounded-full px-2.5 py-0.5 text-xs font-semibold ${map[status]}`}
    >
      {statusLabels[status] ?? status}
    </span>
  )
}

function StatusButton({
  active,
  tone,
  onClick,
  children,
}: {
  active: boolean
  tone: 'taken' | 'skipped' | 'open'
  onClick: () => void
  children: string
}) {
  const activeClass =
    tone === 'taken'
      ? 'bg-emerald-600 text-white ring-emerald-600'
      : tone === 'skipped'
        ? 'bg-amber-500 text-white ring-amber-500'
        : 'bg-slate-600 text-white ring-slate-600'
  const idleClass =
    tone === 'taken'
      ? 'bg-emerald-50 text-emerald-800 ring-emerald-200 hover:bg-emerald-100'
      : tone === 'skipped'
        ? 'bg-amber-50 text-amber-900 ring-amber-200 hover:bg-amber-100'
        : 'bg-white text-ink-soft ring-blush-200 hover:bg-blush-50'

  return (
    <button
      type="button"
      onClick={onClick}
      className={`rounded-full px-3 py-1.5 text-xs font-semibold ring-1 transition ${
        active ? activeClass : idleClass
      }`}
    >
      {children}
    </button>
  )
}
