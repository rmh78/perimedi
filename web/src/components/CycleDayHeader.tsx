import { parseISO } from 'date-fns'
import type { Remark, SymptomScore } from '../types'
import type { MessageKey } from '../i18n'
import { useLocale } from '../i18n'
import { PagerRow } from './PagerRow'
import type { DayColumn } from './cycleTypes'
import { BloodDropIcon } from './CycleMarks'

type Props = {
  selectedCol: DayColumn | null
  selectedSymptoms: Remark[]
  selectedScores: SymptomScore[]
  canPagePrev: boolean
  canPageNext: boolean
  onPageDay: (delta: -1 | 1) => void
  onGoToToday: () => void
  onAddSymptom?: (dateKey: string) => void
}

export function CycleDayHeader({
  selectedCol,
  selectedSymptoms,
  selectedScores,
  canPagePrev,
  canPageNext,
  onPageDay,
  onGoToToday,
  onAddSymptom,
}: Props) {
  const { t, formatDate } = useLocale()
  const datePart = selectedCol?.dateKey
    ? formatDate(parseISO(selectedCol.dateKey), 'EEE, MMM d')
    : ''
  const cycleDay = selectedCol?.info?.cycleDay
  const pagerLabel =
    cycleDay != null && datePart
      ? `${t('diagram.dayBadge', { day: cycleDay })} · ${datePart}`
      : cycleDay != null
        ? t('diagram.dayBadge', { day: cycleDay })
        : datePart

  return (
    <div className="border-b border-blush-100/80 px-3 py-2 sm:px-5 sm:py-3">
      {selectedCol ? (
        <PagerRow
          label={pagerLabel}
          todayLabel={t('common.today')}
          prevLabel={t('diagram.prevDay')}
          nextLabel={t('diagram.nextDay')}
          onToday={onGoToToday}
          onPrev={() => onPageDay(-1)}
          onNext={() => onPageDay(1)}
          canPrev={canPagePrev}
          canNext={canPageNext}
        />
      ) : null}

      {selectedCol &&
        (selectedCol.isLoggedPeriod ||
          selectedCol.info?.isPredictedPeriod ||
          selectedSymptoms.length > 0 ||
          selectedScores.length > 0) && (
          <div className="mt-1.5 flex min-w-0 flex-col gap-1">
            <div className="flex flex-wrap items-center gap-1.5">
              {selectedCol.isLoggedPeriod ? (
                <span className="inline-flex items-center gap-1.5 rounded-full bg-rose-100 px-2.5 py-1 text-xs font-semibold leading-none text-rose-800 ring-1 ring-rose-200">
                  <BloodDropIcon size="sm" />
                  {t('diagram.periodTitle')}
                </span>
              ) : selectedCol.info?.isPredictedPeriod ? (
                <span className="inline-flex items-center gap-1.5 rounded-full bg-rose-50 px-2.5 py-1 text-xs font-semibold leading-none text-rose-700 ring-1 ring-rose-100">
                  <BloodDropIcon predicted size="sm" />
                  {t('diagram.predictedPeriodTitle')}
                </span>
              ) : null}
            </div>
            {(selectedScores.length > 0 || selectedSymptoms.length > 0) && (
              <div className="flex min-w-0 flex-wrap items-center gap-1.5">
                {selectedScores.map((s) => {
                  const label = `${t(`symptom.id.${s.id}` as MessageKey)} ${s.severity}${
                    s.count != null ? ` · ${s.count}` : ''
                  }`
                  return (
                    <button
                      key={`${s.date}-${s.id}`}
                      type="button"
                      className="inline-flex max-w-full min-w-0 items-center gap-1.5 rounded-full bg-amber-50 px-2.5 py-1 text-xs font-medium leading-none text-amber-900 ring-1 ring-amber-200 transition hover:text-amber-800"
                      onClick={() => {
                        if (onAddSymptom && selectedCol.dateKey) {
                          onAddSymptom(selectedCol.dateKey)
                        }
                      }}
                    >
                      <span className="min-w-0 truncate leading-none">{label}</span>
                    </button>
                  )
                })}
                {selectedSymptoms.map((s) => (
                  <button
                    key={s.id}
                    type="button"
                    className="inline-flex max-w-full min-w-0 items-center gap-1.5 rounded-full bg-amber-50 px-2.5 py-1 text-xs font-medium leading-none text-amber-900 ring-1 ring-amber-200 transition hover:text-amber-800"
                    title={s.body}
                    onClick={() => {
                      if (onAddSymptom && selectedCol.dateKey) {
                        onAddSymptom(selectedCol.dateKey)
                      }
                    }}
                  >
                    <svg
                      viewBox="0 0 12 14"
                      className="h-3 w-2.5 shrink-0"
                      aria-hidden
                    >
                      <path
                        d="M6.8 1.2 2.4 7.6h3.1L4.6 12.8l5.2-7.2H6.6L6.8 1.2Z"
                        fill="#c47f00"
                      />
                    </svg>
                    <span className="min-w-0 truncate leading-none">{s.body}</span>
                  </button>
                ))}
              </div>
            )}
          </div>
        )}
    </div>
  )
}
