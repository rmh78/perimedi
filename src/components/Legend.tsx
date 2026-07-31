import { useT } from '../i18n'
import { BloodDropIcon } from './CycleMarks'

export function CalendarLegend() {
  const t = useT()
  return (
    <div className="flex flex-wrap gap-x-4 gap-y-2 text-xs text-ink-soft">
      <span className="inline-flex items-center gap-1.5">
        <span className="relative h-3 w-4">
          <span className="absolute inset-x-0 top-0 h-0.5 bg-slate-600" />
          <span className="absolute left-0 top-0 h-2 w-0.5 bg-slate-600" />
        </span>
        {t('legend.cycleStart')}
      </span>
      <span className="inline-flex items-center gap-1.5">
        <span className="relative h-3 w-4">
          <span className="absolute inset-x-0 bottom-0 h-0.5 bg-slate-500" />
          <span className="absolute bottom-0 right-0 h-2 w-0.5 bg-slate-500" />
        </span>
        {t('legend.cycleEnd')}
      </span>
      <span className="inline-flex items-center gap-1.5">
        <span className="rounded-full bg-slate-800/[0.06] px-1 py-px text-[9px] font-semibold text-slate-600">
          D12
        </span>
        {t('legend.cycleDay')}
      </span>
      <span className="inline-flex items-center gap-1.5">
        <BloodDropIcon /> {t('legend.period')}
      </span>
      <span className="inline-flex items-center gap-1.5">
        <BloodDropIcon predicted /> {t('legend.predicted')}
      </span>
      <span className="inline-flex items-center gap-1.5">
        <span className="h-2.5 w-2.5 rounded-full bg-violet-400" />{' '}
        {t('legend.symptom')}
      </span>
      <span className="inline-flex items-center gap-1.5">
        <span className="h-2.5 w-2.5 rounded-full bg-[var(--color-taken)]" />{' '}
        {t('legend.taken')}
      </span>
      <span className="inline-flex items-center gap-1.5">
        <span className="h-2.5 w-2.5 rounded-full bg-[var(--color-pending)]" />{' '}
        {t('legend.notTaken')}
      </span>
    </div>
  )
}
