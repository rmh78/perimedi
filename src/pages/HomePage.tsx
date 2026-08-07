import { useMemo, useState } from 'react'
import { addDays, addMonths, isSameMonth, parseISO } from 'date-fns'
import {
  useCycleSettings,
  useDoseLogs,
  useMedications,
  usePeriods,
  useRemarks,
  useSchedules,
} from '../hooks/useAppData'
import {
  cycleBoundaryMarkers,
  cycleWindowForDate,
  getDayCycleInfo,
  lastPeriodStart,
  nextPredictedPeriodStart,
} from '../lib/cycle'
import { expandPlannedDoses } from '../lib/schedule'
import {
  monthGridDays,
  toDateKey,
  todayKey,
} from '../lib/dates'
import { cycleDayClass } from '../components/CycleBadge'
import { CycleDiagram } from '../components/CycleDiagram'
import { BloodDropIcon } from '../components/CycleMarks'
import { CalendarLegend } from '../components/Legend'
import { EditMedicationSheet } from '../components/EditMedicationSheet'
import { DayNoteSheet } from '../components/DayNoteSheet'
import type { Medication } from '../types'
import { useLocale, formatLongDateLocalized } from '../i18n'
import type { MessageKey } from '../i18n'

export function HomePage() {
  const { t, locale, formatDate } = useLocale()
  const today = todayKey()
  const medications = useMedications()
  const schedules = useSchedules()
  const doseLogs = useDoseLogs()
  const periods = usePeriods()
  const remarks = useRemarks()
  const settings = useCycleSettings()

  const [selected, setSelected] = useState(today)
  const [monthAnchor, setMonthAnchor] = useState(() => new Date())

  const [medSheet, setMedSheet] = useState<{
    open: boolean
    isNew: boolean
    medication: Medication | null
  }>({ open: false, isNew: false, medication: null })
  const [noteSheet, setNoteSheet] = useState<{ open: boolean; dateKey: string }>(
    { open: false, dateKey: today },
  )

  const monthGrid = monthGridDays(monthAnchor)
  const monthFrom = toDateKey(monthGrid[0])
  const monthTo = toDateKey(monthGrid[monthGrid.length - 1])

  const latestCycleStart = lastPeriodStart(periods)
  const latestCycleLen = Math.max(
    settings.averagePeriodLength + 2,
    settings.averageCycleLength,
  )
  const latestCycleEnd = latestCycleStart
    ? toDateKey(addDays(parseISO(latestCycleStart), latestCycleLen - 1))
    : null

  // Cycle window for the selected calendar day (may differ from latest cycle)
  const selectedWindow = cycleWindowForDate(selected, periods, settings)
  const selectedWindowEnd = toDateKey(
    addDays(parseISO(selectedWindow.start), selectedWindow.length - 1),
  )

  // Include selected cycle window so calendar picks load the right med lanes.
  const rangeStart = [
    today,
    selected,
    monthFrom,
    selectedWindow.start,
    ...(latestCycleStart ? [latestCycleStart] : []),
  ].sort()[0]
  const rangeEnd = [
    today,
    selected,
    monthTo,
    selectedWindowEnd,
    ...(latestCycleEnd ? [latestCycleEnd] : []),
  ]
    .sort()
    .at(-1)!

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

  const todayDoses = allDoses.filter((d) => d.date === today)
  const todayInfo = getDayCycleInfo(today, periods, settings)
  const nextPeriod = nextPredictedPeriodStart(periods, settings)

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

  const taken = todayDoses.filter((d) => d.status === 'taken').length
  const total = todayDoses.length
  const progress = total ? Math.round((taken / total) * 100) : 0

  const weekdayKeys: MessageKey[] = [
    'weekday.0',
    'weekday.1',
    'weekday.2',
    'weekday.3',
    'weekday.4',
    'weekday.5',
    'weekday.6',
  ]

  function openEditMed(medicationId: string) {
    const med = medications.find((m) => m.id === medicationId) ?? null
    setMedSheet({ open: true, isNew: false, medication: med })
  }

  function openAddMed() {
    setMedSheet({ open: true, isNew: true, medication: null })
  }

  function openAddSymptom(dateKey: string) {
    setNoteSheet({ open: true, dateKey })
  }

  return (
    <div className="space-y-3 sm:space-y-5">
      {/* Hero: compact on SE — text + dose ring side-by-side */}
      <section className="glass-card relative overflow-hidden rounded-2xl p-3 sm:rounded-[1.75rem] sm:p-6">
        <div className="pointer-events-none absolute -right-8 -top-10 h-36 w-36 rounded-full bg-blush-200/50 blur-2xl" />
        <div className="pointer-events-none absolute -bottom-10 left-10 h-28 w-28 rounded-full bg-lilac-200/40 blur-2xl" />

        <div className="relative flex flex-row items-center justify-between gap-3 sm:items-start sm:gap-5">
          <div className="min-w-0 flex-1 space-y-1 sm:space-y-3">
            <p className="text-[10px] font-semibold uppercase tracking-[0.16em] text-blush-600 sm:text-xs sm:tracking-[0.2em]">
              {formatLongDateLocalized(today, locale)}
            </p>
            <h2 className="font-display text-2xl font-semibold leading-tight text-blush-900 sm:text-4xl">
              {todayInfo.cycleDay != null
                ? t('home.cycleDay', { day: todayInfo.cycleDay })
                : t('home.yourDay')}
            </h2>
            {nextPeriod && (
              <p className="text-xs text-ink-soft sm:text-sm">
                {t('home.nextPeriod')}{' '}
                <span className="font-medium text-blush-800">
                  {formatLongDateLocalized(nextPeriod, locale)}
                </span>
              </p>
            )}
          </div>

          <div className="flex w-auto shrink-0 flex-col items-center rounded-2xl bg-gradient-to-b from-blush-50 to-white p-2 ring-1 ring-blush-100 sm:rounded-3xl sm:p-4">
            <div
              className="relative flex h-16 w-16 items-center justify-center rounded-full sm:h-24 sm:w-24"
              style={{
                background: `conic-gradient(#e85a84 ${progress}%, #fce7ef ${progress}%)`,
              }}
            >
              <div className="flex h-12 w-12 flex-col items-center justify-center rounded-full bg-white sm:h-[4.5rem] sm:w-[4.5rem]">
                <span className="font-display text-lg font-semibold text-blush-800 sm:text-2xl">
                  {total ? `${taken}/${total}` : t('common.emDash')}
                </span>
                <span className="text-[8px] font-medium uppercase tracking-wide text-ink-muted sm:text-[10px]">
                  {t('home.taken')}
                </span>
              </div>
            </div>
            <p className="mt-1 text-center text-[10px] text-ink-soft sm:mt-2 sm:text-xs">
              {t('home.dosesToday')}
            </p>
          </div>
        </div>
      </section>

      {/* Cycle days, period, symptoms + meds */}
      <CycleDiagram
        periods={periods}
        settings={settings}
        doses={allDoses}
        remarks={remarks}
        selectedDate={selected}
        onSelectDate={setSelected}
        todayKey={today}
        onAddMedication={openAddMed}
        onEditMedication={openEditMed}
        onAddSymptom={openAddSymptom}
      />

      {/* Month calendar */}
      <section className="glass-card rounded-2xl p-3 sm:rounded-[1.75rem] sm:p-5">
        <div className="mb-2 flex flex-wrap items-center justify-between gap-2 sm:mb-3 sm:gap-3">
          <div className="min-w-0">
            <h3 className="section-title text-[1.3rem] sm:text-[1.45rem]">
              {t('home.month')}
            </h3>
            <p className="text-sm text-ink-soft">
              {formatDate(monthAnchor, 'MMMM yyyy')}
            </p>
          </div>
          <div className="flex gap-1.5">
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
                setSelected(today)
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

        <div className="mt-3 overflow-hidden rounded-2xl ring-1 ring-blush-100">
          <div className="grid grid-cols-7 bg-blush-50/80">
            {weekdayKeys.map((key) => (
              <div
                key={key}
                className="px-1 py-2 text-center text-[10px] font-semibold uppercase tracking-wide text-ink-muted"
              >
                {t(key)}
              </div>
            ))}
          </div>
          <div className="grid grid-cols-7 bg-white/50">
            {monthGrid.map((day) => {
              const key = toDateKey(day)
              const info = getDayCycleInfo(key, periods, settings)
              const dayDoses = allDoses.filter((d) => d.date === key)
              const daySymptoms = symptomsByDate.get(key) ?? []
              const cycleMark = cycleMarks.get(key)
              const isCycleStart = Boolean(cycleMark?.isStart)
              const isCycleEnd = Boolean(cycleMark?.isEnd)
              const inMonth = isSameMonth(day, monthAnchor)
              const isSelected = selected === key
              const isToday = key === today
              return (
                <button
                  key={key}
                  type="button"
                  onClick={() => setSelected(key)}
                  aria-current={isToday ? 'date' : undefined}
                  title={[
                    formatDate(day, 'MMM d'),
                    info.cycleDay != null
                      ? t('home.cycleDay', { day: info.cycleDay })
                      : null,
                    isCycleStart ? t('home.cycleStart') : null,
                    isCycleEnd ? t('home.cycleEnd') : null,
                    info.isLoggedPeriod
                      ? t('home.period')
                      : info.isPredictedPeriod
                        ? t('home.predictedPeriod')
                        : null,
                    daySymptoms.length
                      ? t('home.symptomsCount', { count: daySymptoms.length })
                      : null,
                  ]
                    .filter(Boolean)
                    .join(' · ')}
                  className={`relative min-h-11 border-b border-r border-blush-50 p-1.5 text-left transition sm:min-h-[4.5rem] ${cycleDayClass(info)} ${
                    !inMonth ? 'opacity-35' : ''
                  } ${
                    isSelected
                      ? 'ring-2 ring-inset ring-blush-500'
                      : ''
                  } ${
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

                  <div className="flex items-start justify-between gap-0.5">
                    <div className="flex flex-col items-start gap-0.5">
                      <span
                        className={`inline-flex h-6 min-w-6 items-center justify-center rounded-full text-xs font-bold sm:text-sm ${
                          isToday
                            ? 'bg-blush-600 px-1.5 text-white shadow-sm'
                            : info.isLoggedPeriod
                              ? 'text-rose-800'
                              : 'text-ink'
                        }`}
                      >
                        {formatDate(day, 'd')}
                      </span>
                      {info.cycleDay != null && (
                        <span
                          className="rounded-full bg-slate-800/[0.06] px-1.5 py-px text-[9px] font-semibold tabular-nums text-slate-600"
                          title={t('home.cycleDay', { day: info.cycleDay })}
                        >
                          D{info.cycleDay}
                        </span>
                      )}
                    </div>
                    <div className="flex flex-col items-end gap-0.5">
                      {isToday && (
                        <span className="rounded-full bg-blush-600/10 px-1 py-px text-[8px] font-bold uppercase tracking-wide text-blush-700">
                          {t('common.today')}
                        </span>
                      )}
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
                          size="md"
                        />
                      )}
                    </div>
                  </div>

                  <div className="mt-1.5 flex flex-wrap items-center gap-0.5">
                    {daySymptoms.slice(0, 3).map((s) => (
                      <span
                        key={s.id}
                        className="h-1.5 w-1.5 rounded-full bg-violet-400"
                        title={s.body}
                      />
                    ))}
                    {daySymptoms.length > 3 && (
                      <span className="text-[8px] font-bold text-violet-600">
                        +{daySymptoms.length - 3}
                      </span>
                    )}
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

      <EditMedicationSheet
        open={medSheet.open}
        medication={medSheet.medication}
        isNew={medSheet.isNew}
        onClose={() =>
          setMedSheet({ open: false, isNew: false, medication: null })
        }
        onSaved={() => {
          setMedSheet({ open: false, isNew: false, medication: null })
        }}
      />

      <DayNoteSheet
        open={noteSheet.open}
        dateKey={noteSheet.dateKey}
        onClose={() => setNoteSheet({ open: false, dateKey: today })}
        onSaved={() => setNoteSheet({ open: false, dateKey: today })}
      />
    </div>
  )
}
