import { parseISO } from 'date-fns'
import type { Remark } from '../types'
import { deleteRemark } from '../db/actions'
import { useConfirm } from '../context/ConfirmContext'
import { useLocale } from '../i18n'
import { PagerRow } from './PagerRow'
import type { DayColumn } from './cycleTypes'

type Props = {
  selectedCol: DayColumn | null
  selectedSymptoms: Remark[]
  canPagePrev: boolean
  canPageNext: boolean
  onPageDay: (delta: -1 | 1) => void
  onGoToToday: () => void
  onAddSymptom?: (dateKey: string) => void
}

export function CycleDayHeader({
  selectedCol,
  selectedSymptoms,
  canPagePrev,
  canPageNext,
  onPageDay,
  onGoToToday,
  onAddSymptom,
}: Props) {
  const { t, formatDate } = useLocale()
  const confirm = useConfirm()

  return (
    <div className="border-b border-blush-100/80 px-3 py-2 sm:px-5 sm:py-3">
      {selectedCol ? (
        <PagerRow
          label={`${t('diagram.dayBadge', { day: selectedCol.cycleDay })}${
            selectedCol.dateKey
              ? ` · ${formatDate(parseISO(selectedCol.dateKey), 'EEE, MMM d')}`
              : ''
          }`}
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
          selectedSymptoms.length > 0) && (
          <div className="mt-1.5 flex min-w-0 flex-col gap-1">
            <div className="flex flex-wrap items-center gap-1.5">
              {selectedCol.isLoggedPeriod ? (
                <span className="inline-flex items-center gap-1.5 rounded-full bg-rose-100 px-2.5 py-1 text-xs font-semibold leading-none text-rose-800 ring-1 ring-rose-200">
                  <span className="h-2 w-2 rounded-full bg-rose-500" />
                  {t('diagram.periodTitle')}
                </span>
              ) : selectedCol.info?.isPredictedPeriod ? (
                <span className="inline-flex items-center gap-1.5 rounded-full bg-rose-50 px-2.5 py-1 text-xs font-semibold leading-none text-rose-700 ring-1 ring-rose-100">
                  <span className="h-2 w-2 rounded-full bg-rose-300" />
                  {t('diagram.predictedPeriodTitle')}
                </span>
              ) : null}
            </div>
            {selectedSymptoms.length > 0 && (
              <div className="flex min-w-0 flex-wrap items-center gap-1.5">
                {selectedSymptoms.map((s) => (
                  <div
                    key={s.id}
                    className="inline-flex max-w-full min-w-0 items-center gap-1 rounded-full bg-violet-50 py-1 pl-2.5 pr-1 text-xs font-medium leading-none text-violet-900 ring-1 ring-violet-100"
                  >
                    <button
                      type="button"
                      className="inline-flex min-w-0 max-w-full items-center gap-1.5 text-left leading-none transition hover:text-violet-700"
                      title={s.body}
                      onClick={() => {
                        if (onAddSymptom && selectedCol.dateKey) {
                          onAddSymptom(selectedCol.dateKey)
                        }
                      }}
                    >
                      <span className="h-2 w-2 shrink-0 rounded-full bg-violet-400" />
                      <span className="min-w-0 truncate leading-none">
                        {s.body}
                      </span>
                    </button>
                    <button
                      type="button"
                      className="inline-flex h-4 w-4 shrink-0 items-center justify-center rounded-full text-sm leading-none text-violet-700 transition hover:bg-violet-100"
                      aria-label={t('common.delete')}
                      title={t('common.delete')}
                      onClick={() => {
                        void confirm({
                          message: t('symptom.deleteConfirm'),
                          danger: true,
                        }).then((ok) => {
                          if (ok) void deleteRemark(s.id)
                        })
                      }}
                    >
                      ×
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
    </div>
  )
}
