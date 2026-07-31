import { useT } from '../i18n'
import type { DayCycleInfo } from '../types'

export function CycleBadge({ info }: { info: DayCycleInfo }) {
  const t = useT()
  const chips: { label: string; className: string }[] = []

  if (info.isLoggedPeriod) {
    chips.push({
      label: t('badge.period'),
      className: 'bg-blush-100 text-blush-800 ring-blush-200',
    })
  } else if (info.isPredictedPeriod) {
    chips.push({
      label: t('badge.predicted'),
      className: 'bg-blush-50 text-blush-700 ring-blush-100',
    })
  }

  if (info.cycleDay != null) {
    chips.push({
      label: t('badge.day', { day: info.cycleDay }),
      className: 'bg-white/80 text-ink-soft ring-blush-100',
    })
  }

  if (chips.length === 0) {
    return (
      <span className="text-sm text-ink-muted">{t('badge.noCycleData')}</span>
    )
  }

  return (
    <div className="flex flex-wrap gap-1.5">
      {chips.map((c) => (
        <span
          key={c.label}
          className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ring-1 ring-inset ${c.className}`}
        >
          {c.label}
        </span>
      ))}
    </div>
  )
}

export function cycleDayClass(info: DayCycleInfo): string {
  if (info.isLoggedPeriod) return 'bg-blush-100 ring-blush-200'
  if (info.isPredictedPeriod) return 'bg-blush-50 ring-blush-100'
  return 'bg-white/70 ring-blush-100/80'
}
