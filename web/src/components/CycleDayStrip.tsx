import { useLocale } from '../i18n'
import { BloodDropIcon, SymptomMarkIcon } from './CycleMarks'
import type { DayColumn } from './cycleTypes'

type Props = {
  columns: DayColumn[]
  cycleLen: number
  gridTemplate: string
  selectedDay: number
  onSelectDay: (col: DayColumn) => void
}

export function CycleDayStrip({
  columns,
  cycleLen: _cycleLen,
  gridTemplate,
  selectedDay,
  onSelectDay,
}: Props) {
  const { t } = useLocale()
  return (
    <div className="overflow-hidden rounded-2xl bg-white/80 ring-1 ring-blush-100">
      <div
        className="grid"
        style={{
          gridTemplateColumns: gridTemplate,
        }}
      >
        {columns.map((col) => {
          const active = col.cycleDay === selectedDay
          return (
            <button
              key={col.cycleDay}
              type="button"
              disabled={!col.dateKey}
              aria-current={col.isToday ? 'date' : undefined}
              onClick={() => onSelectDay(col)}
              title={
                col.dateKey
                  ? [
                      t('diagram.dayN', { day: col.cycleDay }),
                      col.dateKey,
                      col.isLoggedPeriod ? t('diagram.periodTitle') : null,
                      col.symptoms.length
                        ? t('home.symptomsCount', {
                            count: col.symptoms.length,
                          })
                        : null,
                    ]
                      .filter(Boolean)
                      .join(' · ')
                  : t('diagram.dayN', { day: col.cycleDay })
              }
              className={`flex min-h-10 flex-col items-center justify-end gap-px border-r border-blush-50 px-px py-1 transition last:border-r-0 ${
                col.isLoggedPeriod
                  ? 'bg-rose-100/80'
                  : col.info?.isPredictedPeriod
                    ? 'bg-rose-50/70'
                    : 'hover:bg-blush-50/80'
              } ${active ? 'bg-blush-50/50' : ''} ${
                !col.dateKey ? 'cursor-default opacity-60' : 'cursor-pointer'
              }`}
            >
              {/* Row 1: period blood drops */}
              <div className="flex h-2.5 w-full items-center justify-center">
                {(col.isLoggedPeriod || col.info?.isPredictedPeriod) && (
                  <BloodDropIcon
                    predicted={
                      !col.isLoggedPeriod &&
                      Boolean(col.info?.isPredictedPeriod)
                    }
                    title={
                      col.isLoggedPeriod
                        ? t('diagram.periodTitle')
                        : t('diagram.predictedPeriodTitle')
                    }
                  />
                )}
              </div>
              {/* One mark only — narrow day columns overflow with multiple icons */}
              <div className="flex h-2.5 w-full items-center justify-center">
                {col.symptoms[0] && (
                  <SymptomMarkIcon
                    kind={col.symptoms[0].kind}
                    title={
                      col.symptoms.length > 1
                        ? t('home.symptomsCount', {
                            count: col.symptoms.length,
                          })
                        : col.symptoms[0].body
                    }
                  />
                )}
              </div>

              <span
                className={`inline-flex h-5 min-w-5 items-center justify-center rounded-full text-[11px] font-semibold leading-none ${
                  col.isToday
                    ? 'bg-blush-600 px-1 text-white shadow-sm'
                    : active
                      ? 'text-blush-700'
                      : col.isLoggedPeriod
                        ? 'text-rose-800'
                        : 'text-ink-muted'
                }`}
              >
                {col.cycleDay}
              </span>
            </button>
          )
        })}
      </div>
    </div>
  )
}
