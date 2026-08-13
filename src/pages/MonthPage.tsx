import { useMemo, useState } from 'react'
import { addMonths, isSameMonth } from 'date-fns'
import {
  useCycleSettings,
  useDoseLogs,
  useMedications,
  usePeriods,
  useRemarks,
  useSchedules,
} from '../hooks/useAppData'
import { cycleBoundaryMarkers, getDayCycleInfo } from '../lib/cycle'
import { expandPlannedDoses } from '../lib/schedule'
import { doseExpansionRange } from '../lib/doseRange'
import { monthGridDays, toDateKey, todayKey } from '../lib/dates'
import { cycleDayClass } from '../components/CycleBadge'
import { BloodDropIcon } from '../components/CycleMarks'
import { CalendarLegend } from '../components/Legend'
import { useLocale } from '../i18n'
import type { MessageKey } from '../i18n'
import { useSelectedDate } from '../context/SelectedDateContext'

export function MonthPage() {
  const { t, formatDate } = useLocale()
  const today = todayKey()
  const { selectedDate, setSelectedDate, goToToday } = useSelectedDate()
  const medications = useMedications()
  const schedules = useSchedules()
  const doseLogs = useDoseLogs()
  const periods = usePeriods()
  const remarks = useRemarks()
  const settings = useCycleSettings()
  const [monthAnchor, setMonthAnchor] = useState(() => new Date())

  const monthGrid = monthGridDays(monthAnchor)
  const monthFrom = toDateKey(monthGrid[0])
  const monthTo = toDateKey(monthGrid[monthGrid.length - 1])

  const { from: rangeStart, to: rangeEnd } = doseExpansionRange({
    today,
    selectedDate,
    periods,
    settings,
    extraFrom: [monthFrom],
    extraTo: [monthTo],
  })

  const allDoses = useMemo(
    () =>
      expandPlannedDoses({
        from: rangeStart,
        to: rangeEnd,
        medications,
        schedules,
        doseLogs,
        periods,
        settings,
      }),
    [rangeStart, rangeEnd, medications, schedules, doseLogs, periods, settings],
  )

  const symptomsByDate = useMemo(() => {
    const map = new Map<string, typeof remarks>()
    for (const r of remarks) {
      if (r.kind !== 'cycle' && r.kind !== 'side_effect' && r.kind !== 'note') {
        continue
      }
      const key = toDateKey(r.occurredOn)
      const list = map.get(key) ?? []
      list.push(r)
      map.set(key, list)
    }
    return map
  }, [remarks])

  const cycleMarks = useMemo(
    () => cycleBoundaryMarkers(monthFrom, monthTo, periods, settings),
    [monthFrom, monthTo, periods, settings],
  )

  const weekdayKeys: MessageKey[] = [
    'weekday.0',
    'weekday.1',
    'weekday.2',
    'weekday.3',
    'weekday.4',
    'weekday.5',
    'weekday.6',
  ]

  return (
    <section className="glass-card rounded-2xl p-3 sm:rounded-[1.75rem] sm:p-5">
      <div className="mb-2 flex items-center justify-between gap-2">
        <p className="min-w-0 truncate text-sm font-semibold text-ink sm:text-base">
          {formatDate(monthAnchor, 'MMMM yyyy')}
        </p>
        <div className="flex shrink-0 gap-1.5">
          <button
            type="button"
            className="btn-ghost !min-h-10 !px-3 !py-2 text-xs"
            onClick={() => setMonthAnchor((d) => addMonths(d, -1))}
          >
            {t('common.prev')}
          </button>
          <button
            type="button"
            className="btn-ghost !min-h-10 !px-3 !py-2 text-xs"
            onClick={() => {
              setMonthAnchor(new Date())
              goToToday()
            }}
          >
            {t('common.today')}
          </button>
          <button
            type="button"
            className="btn-ghost !min-h-10 !px-3 !py-2 text-xs"
            onClick={() => setMonthAnchor((d) => addMonths(d, 1))}
          >
            {t('common.next')}
          </button>
        </div>
      </div>

      <CalendarLegend />

      <div className="mt-3 rounded-2xl ring-1 ring-blush-100">
        <div className="grid grid-cols-7 rounded-t-2xl bg-blush-50/80">
          {weekdayKeys.map((key) => (
            <div
              key={key}
              className="px-1 py-2 text-center text-[10px] font-semibold uppercase tracking-wide text-ink-muted"
            >
              {t(key)}
            </div>
          ))}
        </div>
        <div className="grid grid-cols-7 overflow-visible rounded-b-2xl bg-white/50">
          {monthGrid.map((day) => {
            const key = toDateKey(day)
            const info = getDayCycleInfo(key, periods, settings)
            const dayDoses = allDoses.filter((d) => d.date === key)
            const daySymptoms = symptomsByDate.get(key) ?? []
            const cycleMark = cycleMarks.get(key)
            const isCycleStart = Boolean(cycleMark?.isStart)
            const isCycleEnd = Boolean(cycleMark?.isEnd)
            const inMonth = isSameMonth(day, monthAnchor)
            const isSelected = selectedDate === key
            const isToday = key === today
            return (
              <button
                key={key}
                type="button"
                onClick={() => setSelectedDate(key)}
                aria-current={isToday ? 'date' : undefined}
                className={`relative min-h-11 border-b border-r border-blush-50 p-1.5 text-left transition sm:min-h-[4.5rem] ${cycleDayClass(info)} ${
                  !inMonth ? 'opacity-35' : ''
                } ${isSelected ? 'ring-2 ring-inset ring-blush-500' : ''} ${
                  isToday && !isSelected
                    ? 'ring-2 ring-inset ring-blush-400/70'
                    : ''
                } ${
                  info.isLoggedPeriod
                    ? 'bg-rose-100/70'
                    : info.isPredictedPeriod
                      ? 'bg-rose-50/80'
                      : isToday
                        ? 'bg-blush-50/90'
                        : ''
                }`}
              >
                {isCycleStart && (
                  <>
                    <span
                      className="absolute inset-x-0 top-0 h-0.5 bg-slate-600/70"
                      aria-hidden
                    />
                    <span
                      className="absolute left-0 top-0 h-2.5 w-0.5 bg-slate-600/70"
                      aria-hidden
                    />
                  </>
                )}
                {isCycleEnd && (
                  <>
                    <span
                      className="absolute inset-x-0 bottom-0 h-0.5 bg-slate-500/60"
                      aria-hidden
                    />
                    <span
                      className="absolute bottom-0 right-0 h-2.5 w-0.5 bg-slate-500/60"
                      aria-hidden
                    />
                  </>
                )}
                {/* Day + drop stay left of the cell so the drop is never cut by the right border. */}
                <div className="flex flex-col items-start gap-0.5">
                  <div className="flex items-center gap-0.5">
                    <span
                      className={`inline-flex h-6 min-w-6 items-center justify-center rounded-full text-xs font-bold ${
                        isToday
                          ? 'bg-blush-600 px-1.5 text-white shadow-sm'
                          : info.isLoggedPeriod
                            ? 'text-rose-800'
                            : 'text-ink'
                      }`}
                    >
                      {formatDate(day, 'd')}
                    </span>
                    {(info.isLoggedPeriod || info.isPredictedPeriod) && (
                      <BloodDropIcon
                        predicted={
                          !info.isLoggedPeriod && info.isPredictedPeriod
                        }
                        title={
                          info.isLoggedPeriod
                            ? t('home.period')
                            : t('home.predictedPeriod')
                        }
                        size="sm"
                      />
                    )}
                  </div>
                  {info.cycleDay != null && (
                    <span className="rounded-full bg-slate-800/[0.06] px-1.5 py-px text-[9px] font-semibold tabular-nums text-slate-600">
                      D{info.cycleDay}
                    </span>
                  )}
                </div>
                <div className="mt-1.5 flex flex-wrap items-center gap-0.5">
                  {daySymptoms.slice(0, 3).map((s) => (
                    <span
                      key={s.id}
                      className="h-1.5 w-1.5 rounded-full bg-violet-400"
                      title={s.body}
                    />
                  ))}
                  {dayDoses.slice(0, 3).map((d) => (
                    <span
                      key={d.key}
                      className={`h-1.5 w-1.5 rounded-full ${
                        d.status === 'taken'
                          ? 'bg-[var(--color-taken)]'
                          : 'bg-[var(--color-pending)]'
                      }`}
                    />
                  ))}
                </div>
              </button>
            )
          })}
        </div>
      </div>
    </section>
  )
}
