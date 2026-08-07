import {
  useCallback,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react'
import { addDays, parseISO } from 'date-fns'
import type {
  CycleSettings,
  DayCycleInfo,
  Period,
  PlannedDose,
  Remark,
} from '../types'
import { cycleWindowForDate, getDayCycleInfo } from '../lib/cycle'
import { toDateKey } from '../lib/dates'
import {
  buildMedLanes,
  type DoseSegment,
  type MedLane,
} from '../lib/medSegments'
import { MedFormIcon } from './MedFormIcon'
import { deleteRemark, setDoseStatus } from '../db/actions'
import { PeriodSettingsSheet } from './PeriodSettingsSheet'
import { BloodDropIcon, SymptomMarkIcon } from './CycleMarks'
import { iconBgFromColor, takenFillFromColor } from '../lib/medColors'
import { useLocale } from '../i18n'
import { computeDayScrollLeft } from '../lib/chartScroll'
import {
  CYCLE_DAY_MIN_PX,
  CYCLE_DOSE_META_MAX_WIDTH_PX,
  CYCLE_DOSE_META_STICKY_LEFT_PX,
  CYCLE_LABEL_COL_PX,
  CYCLE_LABEL_PAD_LEFT_PX,
  CYCLE_MED_RING_PX,
  selectedDayPlotLeftPct,
  selectedDayPlotWidthPct,
} from '../lib/cycleLayout'

type Props = {
  periods: Period[]
  settings: CycleSettings
  doses: PlannedDose[]
  remarks?: Remark[]
  selectedDate: string
  onSelectDate: (dateKey: string) => void
  todayKey: string
  onAddMedication?: () => void
  onEditMedication?: (medicationId: string) => void
  onAddSymptom?: (dateKey: string) => void
}

type DayColumn = {
  cycleDay: number
  dateKey: string | null
  info: DayCycleInfo | null
  isToday: boolean
  isSelected: boolean
  /** Logged or predicted period */
  isPeriod: boolean
  isLoggedPeriod: boolean
  symptoms: Remark[]
}

/** Binary adherence for the selected day: taken or not. */
type TakenState = 'taken' | 'open' | null

const DAY_MIN_PX = CYCLE_DAY_MIN_PX
const LABEL_COL_PX = CYCLE_LABEL_COL_PX
const LABEL_PAD_LEFT_PX = CYCLE_LABEL_PAD_LEFT_PX
const MED_RING_PX = CYCLE_MED_RING_PX

function isSymptomRemark(r: Remark): boolean {
  return r.kind === 'cycle' || r.kind === 'side_effect' || r.kind === 'note'
}

function dayGridTemplate(cycleLen: number): string {
  return `repeat(${cycleLen}, minmax(${DAY_MIN_PX}px, 1fr))`
}

function takenStateFromDoses(dayDoses: PlannedDose[]): TakenState {
  if (dayDoses.length === 0) return null
  return dayDoses.every((d) => d.status === 'taken') ? 'taken' : 'open'
}

export function CycleDiagram({
  periods,
  settings,
  doses,
  remarks = [],
  selectedDate,
  onSelectDate,
  todayKey: today,
  onAddMedication,
  onEditMedication,
  onAddSymptom,
}: Props) {
  const { t, formatDate } = useLocale()
  const [periodSettingsOpen, setPeriodSettingsOpen] = useState(false)
  const plotScrollRef = useRef<HTMLDivElement>(null)
  /** When set, scroll the plot so this date's column is visible after layout. */
  const [scrollToDate, setScrollToDate] = useState<string | null>(null)
  /** One-shot per mount: scroll to current selectedDate after plot layout (never force today). */
  const didInitialScrollToSelected = useRef(false)

  // Anchor the chart to the cycle that contains the selected calendar day
  // (not always the latest period — month picks can be in another cycle).
  const cycleWindow = useMemo(
    () => cycleWindowForDate(selectedDate, periods, settings),
    [selectedDate, periods, settings],
  )
  const cycleStart = cycleWindow.start
  const cycleLen = cycleWindow.length

  const remarksByDate = useMemo(() => {
    const map = new Map<string, Remark[]>()
    for (const r of remarks) {
      if (!isSymptomRemark(r)) continue
      const key = toDateKey(r.occurredOn)
      const list = map.get(key) ?? []
      list.push(r)
      map.set(key, list)
    }
    return map
  }, [remarks])

  const columns: DayColumn[] = useMemo(() => {
    return Array.from({ length: cycleLen }, (_, i) => {
      const cycleDay = i + 1
      const dateKey = cycleStart
        ? toDateKey(addDays(parseISO(cycleStart), cycleDay - 1))
        : null
      const info = dateKey
        ? getDayCycleInfo(dateKey, periods, settings)
        : null
      const symptoms = dateKey ? remarksByDate.get(dateKey) ?? [] : []
      return {
        cycleDay,
        dateKey,
        info,
        isToday: dateKey === today,
        isSelected: dateKey === selectedDate,
        isPeriod: Boolean(info?.isLoggedPeriod || info?.isPredictedPeriod),
        isLoggedPeriod: Boolean(info?.isLoggedPeriod),
        symptoms,
      }
    })
  }, [
    cycleLen,
    cycleStart,
    periods,
    settings,
    today,
    selectedDate,
    remarksByDate,
  ])

  const lanes = useMemo(
    () => buildMedLanes(doses, cycleStart, cycleLen),
    [doses, cycleStart, cycleLen],
  )

  const selectedCol =
    columns.find((c) => c.dateKey === selectedDate) ?? null

  const selectedDay = selectedCol?.cycleDay ?? 1

  const selectedDayDoses = useMemo(() => {
    return doses
      .filter((d) => d.date === selectedDate)
      .sort((a, b) => a.timeOfDay.localeCompare(b.timeOfDay))
  }, [doses, selectedDate])

  const selectedSymptoms = selectedCol?.symptoms ?? remarksByDate.get(selectedDate) ?? []

  const plotMinWidth = Math.max(cycleLen * DAY_MIN_PX, DAY_MIN_PX)
  const chartMinWidth = LABEL_COL_PX + plotMinWidth
  const gridCols = dayGridTemplate(cycleLen)
  const plotDayLeftPct = selectedDayPlotLeftPct(selectedDay, cycleLen)
  const plotDayWidthPct = selectedDayPlotWidthPct(cycleLen)

  /**
   * Scroll so `cycleDay` is centered in the visible plot (right of sticky labels).
   * Returns false when layout is not ready (common on Firefox first paint / RDM).
   */
  const scrollDayIntoView = useCallback(
    (cycleDay: number, behavior: ScrollBehavior = 'smooth'): boolean => {
      const scroller = plotScrollRef.current
      if (!scroller || cycleLen <= 0) return false
      const content = scroller.firstElementChild as HTMLElement | null
      if (!content) return false

      // Force layout; Firefox mobile/RDM often reports stale widths before this.
      void scroller.offsetWidth
      void content.offsetWidth

      const clientW = scroller.clientWidth
      const contentWidth = Math.max(content.scrollWidth, content.offsetWidth)
      const target = computeDayScrollLeft({
        cycleDay,
        cycleLen,
        labelColPx: LABEL_COL_PX,
        dayMinPx: DAY_MIN_PX,
        clientWidth: clientW,
        contentWidth,
        chartMinWidth,
      })
      if (target == null) return false

      try {
        scroller.scrollTo({ left: target, behavior })
      } catch {
        scroller.scrollLeft = target
      }
      // Firefox sometimes ignores scrollTo options; set as fallback when instant.
      if (behavior === 'auto' && Math.abs(scroller.scrollLeft - target) > 2) {
        scroller.scrollLeft = target
      }
      return true
    },
    [cycleLen, chartMinWidth],
  )

  useLayoutEffect(() => {
    if (!scrollToDate) return
    if (selectedDate !== scrollToDate) return
    const col =
      columns.find((c) => c.dateKey === scrollToDate) ??
      columns.find((c) => c.isToday)
    if (!col) {
      setScrollToDate(null)
      return
    }

    let cancelled = false
    let attempts = 0
    const maxAttempts = 16

    const tryScroll = () => {
      if (cancelled) return
      attempts += 1
      // Button-driven Today: prefer smooth after layout is ready.
      const ok = scrollDayIntoView(
        col.cycleDay,
        attempts === 1 ? 'smooth' : 'auto',
      )
      if (ok || attempts >= maxAttempts) {
        setScrollToDate(null)
        return
      }
      requestAnimationFrame(tryScroll)
    }

    requestAnimationFrame(() => {
      requestAnimationFrame(tryScroll)
    })
    const t1 = window.setTimeout(tryScroll, 50)
    const t2 = window.setTimeout(tryScroll, 200)

    return () => {
      cancelled = true
      window.clearTimeout(t1)
      window.clearTimeout(t2)
    }
  }, [scrollToDate, selectedDate, columns, scrollDayIntoView])

  // On chart mount, scroll to the shared selectedDate (do NOT force today —
  // SelectedDateContext owns the date; remounting Cycle must not wipe Month picks).
  useLayoutEffect(() => {
    if (didInitialScrollToSelected.current) return
    if (lanes.length === 0 || !plotScrollRef.current) return

    const selectedColInWindow =
      columns.find((c) => c.dateKey === selectedDate) ??
      columns.find((c) => c.isToday)
    if (!selectedColInWindow) return

    let cancelled = false
    let attempts = 0
    const maxAttempts = 20
    const day = selectedColInWindow.cycleDay

    const tryScroll = () => {
      if (cancelled || didInitialScrollToSelected.current) return
      attempts += 1
      const ok = scrollDayIntoView(day, 'auto')
      if (ok || attempts >= maxAttempts) {
        didInitialScrollToSelected.current = true
        return
      }
      requestAnimationFrame(tryScroll)
    }

    requestAnimationFrame(() => {
      requestAnimationFrame(tryScroll)
    })
    const t1 = window.setTimeout(tryScroll, 50)
    const t2 = window.setTimeout(tryScroll, 150)
    const t3 = window.setTimeout(tryScroll, 400)

    return () => {
      cancelled = true
      window.clearTimeout(t1)
      window.clearTimeout(t2)
      window.clearTimeout(t3)
    }
  }, [selectedDate, lanes.length, cycleLen, columns, scrollDayIntoView])

  function selectDay(col: DayColumn) {
    if (col.dateKey) onSelectDate(col.dateKey)
  }

  function goToToday() {
    const todayCol = columns.find((c) => c.isToday)
    const dateKey = todayCol?.dateKey ?? today
    onSelectDate(dateKey)
    setScrollToDate(dateKey)
  }

  function pageDay(delta: -1 | 1) {
    if (!selectedCol) return
    const idx = columns.findIndex((c) => c.cycleDay === selectedCol.cycleDay)
    if (idx < 0) return
    const next = columns[idx + delta]
    if (!next?.dateKey) return
    onSelectDate(next.dateKey)
    setScrollToDate(next.dateKey)
  }

  const canPagePrev = Boolean(
    selectedCol &&
      columns.some(
        (c) => c.cycleDay === selectedCol.cycleDay - 1 && c.dateKey,
      ),
  )
  const canPageNext = Boolean(
    selectedCol &&
      columns.some(
        (c) => c.cycleDay === selectedCol.cycleDay + 1 && c.dateKey,
      ),
  )

  return (
    <>
    <section className="glass-card overflow-hidden rounded-2xl sm:rounded-[1.75rem]">
      <div className="border-b border-blush-100/80 px-3 py-2.5 sm:px-5 sm:py-4">
        {/* Day paging takes the full header row; Today on the right */}
        <div className="flex items-center gap-1.5 sm:gap-2">
          {selectedCol ? (
            <div className="flex min-w-0 flex-1 items-center">
              <button
                type="button"
                className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-blush-700 transition hover:bg-blush-100 disabled:pointer-events-none disabled:opacity-35"
                aria-label={t('diagram.prevDay')}
                title={t('diagram.prevDay')}
                disabled={!canPagePrev}
                onClick={() => pageDay(-1)}
              >
                <ChevronLeftIcon />
              </button>
              <p className="min-w-0 flex-1 truncate text-center text-sm font-semibold text-ink sm:text-base">
                {t('diagram.dayBadge', { day: selectedCol.cycleDay })}
                {selectedCol.dateKey
                  ? ` · ${formatDate(parseISO(selectedCol.dateKey), 'EEE, MMM d')}`
                  : ''}
              </p>
              <button
                type="button"
                className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-blush-700 transition hover:bg-blush-100 disabled:pointer-events-none disabled:opacity-35"
                aria-label={t('diagram.nextDay')}
                title={t('diagram.nextDay')}
                disabled={!canPageNext}
                onClick={() => pageDay(1)}
              >
                <ChevronRightIcon />
              </button>
            </div>
          ) : (
            <div className="min-w-0 flex-1" />
          )}

          <button
            type="button"
            className="btn-ghost !min-h-10 shrink-0 !px-3 !py-2 text-xs"
            onClick={goToToday}
          >
            {t('common.today')}
          </button>
        </div>

        {/* Status chips + add actions under the header row */}
        {selectedCol && (
          <div className="mt-2 flex items-start justify-between gap-2 sm:mt-2.5">
            <div className="flex min-w-0 flex-1 flex-col gap-1.5">
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
                ) : (
                  <span className="inline-flex items-center gap-1.5 rounded-full bg-slate-50 px-2.5 py-1 text-xs font-medium leading-none text-ink-muted ring-1 ring-slate-100">
                    {t('diagram.noPeriod')}
                  </span>
                )}
              </div>

              {/* Always under period; wrap side-by-side when there is room. */}
              <div className="flex min-w-0 flex-wrap items-center gap-1.5">
                {selectedSymptoms.length > 0 ? (
                  selectedSymptoms.map((s) => (
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
                          if (confirm(t('symptom.deleteConfirm'))) {
                            void deleteRemark(s.id)
                          }
                        }}
                      >
                        ×
                      </button>
                    </div>
                  ))
                ) : (
                  <span className="inline-flex items-center gap-1.5 rounded-full bg-slate-50 px-2.5 py-1 text-xs font-medium leading-none text-ink-muted ring-1 ring-slate-100">
                    {t('diagram.noSymptoms')}
                  </span>
                )}
              </div>
            </div>

            <div className="flex shrink-0 items-center gap-1.5 pb-0.5 pr-0.5">
              {onAddMedication && (
                <DayActionIconButton
                  label={t('diagram.addMed')}
                  onClick={onAddMedication}
                >
                  <MedFormIcon form="PILL" fill />
                </DayActionIconButton>
              )}
              <DayActionIconButton
                label={t('diagram.cycleSettings')}
                onClick={() => setPeriodSettingsOpen(true)}
              >
                <img
                  src="/ui-icons/cycle-drop.jpg"
                  alt=""
                  className="h-full w-full object-cover"
                  draggable={false}
                />
              </DayActionIconButton>
              {onAddSymptom && selectedCol.dateKey && (
                <DayActionIconButton
                  label={t('diagram.addSymptom')}
                  onClick={() => onAddSymptom(selectedCol.dateKey!)}
                >
                  <img
                    src="/ui-icons/symptom.jpg"
                    alt=""
                    className="h-full w-full object-cover"
                    draggable={false}
                  />
                </DayActionIconButton>
              )}
            </div>
          </div>
        )}
      </div>

      <div className="space-y-1 px-2 py-2.5 sm:px-5 sm:py-4">
        <div className="mb-1 flex flex-wrap items-center gap-x-3 gap-y-1 px-1 sm:gap-x-4">
          <p className="text-[10px] font-semibold uppercase tracking-[0.12em] text-ink-muted sm:text-[11px] sm:tracking-[0.14em]">
            {t('diagram.medsAndDoses')}
          </p>
          <div className="flex flex-wrap gap-3 text-[10px] text-ink-muted">
            <LegendDot className="bg-emerald-500" label={t('diagram.taken')} />
            <LegendDot className="bg-slate-400" label={t('diagram.notTaken')} />
            <span className="inline-flex items-center gap-1">
              <BloodDropIcon />
              {t('diagram.periodTitle')}
            </span>
            <span className="inline-flex items-center gap-1">
              <SymptomMarkIcon />
              {t('legend.symptom')}
            </span>
          </div>
        </div>

        {!cycleStart && (
          <p className="mb-3 rounded-2xl bg-lilac-50/80 px-3 py-2 text-sm text-ink-soft ring-1 ring-lilac-100">
            {t('diagram.periodAlignHint')}
          </p>
        )}

        {lanes.length === 0 ? (
          <div className="relative z-40 flex flex-col items-center justify-center gap-1.5 rounded-2xl border border-dashed border-blush-200 bg-white/70 px-3 py-3.5 text-center shadow-sm sm:gap-3 sm:px-6 sm:py-10">
            <div className="flex h-9 w-9 items-center justify-center rounded-full bg-blush-50 ring-1 ring-blush-100 sm:h-12 sm:w-12">
              <span className="text-base text-blush-500 sm:text-xl" aria-hidden>
                +
              </span>
            </div>
            <div className="space-y-0.5 sm:space-y-1">
              <p className="text-sm font-semibold text-ink sm:text-base">
                {t('diagram.noMedsTitle')}
              </p>
              <p className="max-w-xs text-[11px] leading-snug text-ink-muted sm:text-sm">
                {t('diagram.noMedsBody')}
              </p>
            </div>
            {onAddMedication && (
              <button
                type="button"
                className="btn-primary !min-h-10 !px-4 !py-2 text-sm sm:!px-5"
                onClick={onAddMedication}
              >
                {t('diagram.addMedication')}
              </button>
            )}
          </div>
        ) : (
          /*
            Two-column scroll row: sticky identity (cycle meta + meds) + plot
            (day strip + dose bands). Selection highlight stays plot-only.
          */
          <div
            ref={plotScrollRef}
            /* Do not set touch-pan-x: on iOS it traps vertical gestures so the
               page cannot scroll when the finger starts on the med plot. */
            className="overflow-x-auto overscroll-x-contain [-webkit-overflow-scrolling:touch]"
            data-cycle-plot-scroll
          >
            <div
              className="flex items-stretch"
              style={{ minWidth: chartMinWidth, width: '100%' }}
            >
              <div
                className="sticky left-0 z-30 flex shrink-0 flex-col gap-3 bg-cream pr-2 shadow-[6px_0_10px_-6px_rgba(61,44,51,0.18)]"
                style={{
                  width: LABEL_COL_PX,
                  paddingLeft: LABEL_PAD_LEFT_PX,
                }}
              >
                <div className="flex min-h-10 flex-col justify-center">
                  <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-muted">
                    {t('diagram.cycleDays')}
                  </p>
                  <p className="mt-0.5 text-[10px] text-ink-muted">
                    {t('diagram.cyclePeriodMeta', {
                      cycle: settings.averageCycleLength,
                      period: settings.averagePeriodLength,
                    })}
                  </p>
                </div>
                {lanes.map((lane) => {
                  const dayDoses = selectedDayDoses.filter(
                    (d) => d.medication.id === lane.medicationId,
                  )
                  return (
                    <div
                      key={lane.medicationId}
                      className="flex min-h-11 flex-1 items-center"
                    >
                      <MedLaneLabel
                        lane={lane}
                        dayDoses={dayDoses}
                        onEdit={
                          onEditMedication
                            ? () => onEditMedication(lane.medicationId)
                            : undefined
                        }
                      />
                    </div>
                  )
                })}
              </div>

              <div
                className="relative min-w-0 flex-1"
                style={{ minWidth: plotMinWidth }}
              >
                <div className="relative z-10 flex flex-col gap-3">
                  <CycleDayStrip
                    columns={columns}
                    cycleLen={cycleLen}
                    gridTemplate={gridCols}
                    selectedDay={selectedDay}
                    onSelectDay={selectDay}
                  />
                  {lanes.map((lane) => (
                    <div key={lane.medicationId} className="min-h-11">
                      <MedLaneTrack
                        lane={lane}
                        cycleLen={cycleLen}
                        gridTemplate={gridCols}
                        columns={columns}
                        onSelectDay={selectDay}
                      />
                    </div>
                  ))}
                </div>

                {/* Selection column overlays cycle strip + med bands.
                    pointer-events-none so day cells stay tappable. */}
                <div
                  className="pointer-events-none absolute inset-0 z-[15] overflow-hidden"
                  aria-hidden
                >
                  <div
                    className="absolute inset-y-0 transition-all duration-200"
                    style={{
                      left: `${plotDayLeftPct}%`,
                      width: `${plotDayWidthPct}%`,
                      background: 'rgba(15, 23, 42, 0.14)',
                    }}
                  />
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </section>
    <PeriodSettingsSheet
      open={periodSettingsOpen}
      onClose={() => setPeriodSettingsOpen(false)}
    />
    </>
  )
}

function CycleDayStrip({
  columns,
  cycleLen: _cycleLen,
  gridTemplate,
  selectedDay,
  onSelectDay,
}: {
  columns: DayColumn[]
  cycleLen: number
  gridTemplate: string
  selectedDay: number
  onSelectDay: (col: DayColumn) => void
}) {
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
                className={`text-[9px] font-semibold leading-none ${
                  active
                    ? 'text-blush-700'
                    : col.isToday
                      ? 'text-blush-600'
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

function LegendDot({ className, label }: { className: string; label: string }) {
  return (
    <span className="inline-flex items-center gap-1">
      <span className={`h-2 w-2 rounded-full ${className}`} />
      {label}
    </span>
  )
}

/**
 * Soft 3D circular art button with a shared + badge.
 * Badge sits outside the clipped image circle so it is never cut off.
 */
function DayActionIconButton({
  label,
  onClick,
  children,
}: {
  label: string
  onClick: () => void
  children: ReactNode
}) {
  return (
    <button
      type="button"
      className="relative h-9 w-9 shrink-0 rounded-full transition hover:scale-[1.04] active:scale-95"
      aria-label={label}
      title={label}
      onClick={onClick}
    >
      <span className="absolute inset-0 overflow-hidden rounded-full bg-white shadow-sm ring-1 ring-blush-100/90">
        {children}
      </span>
      <span
        className="pointer-events-none absolute -bottom-0.5 -right-0.5 z-10 flex h-4 w-4 items-center justify-center rounded-full bg-blush-600 text-[11px] font-bold leading-none text-white shadow-md ring-2 ring-white"
        aria-hidden
      >
        +
      </span>
    </button>
  )
}

function ChevronLeftIcon() {
  return (
    <svg
      viewBox="0 0 20 20"
      fill="none"
      className="h-5 w-5"
      aria-hidden
    >
      <path
        d="M12.5 4.5 7 10l5.5 5.5"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}

function ChevronRightIcon() {
  return (
    <svg
      viewBox="0 0 20 20"
      fill="none"
      className="h-5 w-5"
      aria-hidden
    >
      <path
        d="M7.5 4.5 13 10l-5.5 5.5"
        stroke="currentColor"
        strokeWidth="1.75"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}

function MedLaneLabel({
  lane,
  dayDoses,
  onEdit,
}: {
  lane: MedLane
  dayDoses: PlannedDose[]
  onEdit?: () => void
}) {
  const { t } = useLocale()
  const color = lane.color
  const state = takenStateFromDoses(dayDoses)
  const isTaken = state === 'taken'
  const hasDose = state != null

  async function toggleTaken() {
    if (!hasDose) return
    const next = isTaken ? 'pending' : 'taken'
    await Promise.all(
      dayDoses.map((dose) =>
        setDoseStatus({
          medicationId: dose.medication.id,
          scheduleId: dose.schedule.id,
          date: dose.date,
          timeOfDay: dose.timeOfDay,
          status: next,
          existingLogId: dose.log?.id,
        }),
      ),
    )
  }

  const ring = isTaken ? color : hasDose ? `${color}99` : '#f0d0da'
  const statusLabel = isTaken
    ? t('diagram.taken')
    : hasDose
      ? t('diagram.notTaken')
      : t('diagram.noDose')
  const statusColor = isTaken ? color : hasDose ? '#64748b' : undefined

  return (
    <div className="flex w-full min-w-0 items-center gap-1.5 py-1">
      {/*
        Ring is a padded wrapper (not box-shadow): horizontal scrollports clip
        outer shadows on sticky labels, which made the left side of the circle vanish.
      */}
      <span
        className={`relative shrink-0 rounded-full ${
          hasDose ? '' : 'opacity-70'
        }`}
        style={{
          padding: MED_RING_PX,
          background: ring,
        }}
      >
        <button
          type="button"
          disabled={!hasDose}
          onClick={toggleTaken}
          title={
            hasDose
              ? isTaken
                ? t('diagram.markNotTaken', { name: lane.name })
                : t('diagram.markTaken', { name: lane.name })
              : `${lane.name}: ${t('diagram.noDose')}`
          }
          aria-pressed={hasDose ? isTaken : undefined}
          aria-label={
            hasDose
              ? `${lane.name}: ${statusLabel}`
              : `${lane.name}: ${t('diagram.noDose')}`
          }
          className={`relative block h-10 w-10 overflow-hidden rounded-full transition ${
            hasDose
              ? 'cursor-pointer hover:scale-105 active:scale-95'
              : 'cursor-default'
          }`}
          style={{
            background: iconBgFromColor(color, 0.35),
          }}
        >
          <MedFormIcon form={lane.form} fill />
        </button>
        {isTaken && (
          <span
            className="absolute -bottom-0.5 -right-0.5 z-10 flex h-5 w-5 items-center justify-center rounded-full text-[10px] font-bold text-white ring-2 ring-white shadow-sm"
            style={{ background: color }}
            aria-hidden
          >
            ✓
          </span>
        )}
      </span>

      {onEdit ? (
        <button
          type="button"
          className="group min-w-0 flex-1 text-left"
          title={t('diagram.editMed', { name: lane.name })}
          onClick={onEdit}
        >
          <p className="line-clamp-2 break-words text-left text-[12px] font-semibold leading-snug text-ink underline-offset-2 group-hover:underline sm:text-sm">
            {lane.name}
          </p>
          <p
            className="mt-0.5 text-[10px] font-semibold leading-tight"
            style={{ color: statusColor ?? undefined }}
          >
            {statusLabel === t('diagram.noDose') ? (
              <span className="font-medium text-ink-muted">{statusLabel}</span>
            ) : (
              statusLabel
            )}
          </p>
        </button>
      ) : (
        <div className="min-w-0 flex-1 text-left">
          <p className="line-clamp-2 break-words text-[12px] font-semibold leading-snug text-ink sm:text-sm">
            {lane.name}
          </p>
          <p
            className="mt-0.5 text-[10px] font-semibold leading-tight"
            style={{ color: statusColor ?? undefined }}
          >
            {statusLabel === t('diagram.noDose') ? (
              <span className="font-medium text-ink-muted">{statusLabel}</span>
            ) : (
              statusLabel
            )}
          </p>
        </div>
      )}
    </div>
  )
}

function dayIsTaken(cell: {
  statuses: Array<'pending' | 'taken' | 'skipped'>
}) {
  return cell.statuses.length > 0 && cell.statuses.every((s) => s === 'taken')
}

/** Shared track chrome for every med — multi-day bands and single-day doses. */
function MedLaneTrack({
  lane,
  cycleLen: _cycleLen,
  gridTemplate,
  columns,
  onSelectDay,
}: {
  lane: MedLane
  cycleLen: number
  gridTemplate: string
  columns: DayColumn[]
  onSelectDay: (col: DayColumn) => void
}) {
  const { t } = useLocale()
  const color = lane.color
  const byDay = new Map(lane.days.map((d) => [d.cycleDay, d]))
  const takenFill = takenFillFromColor(color, 0.42)

  return (
    <div className="relative">
      <div
        className="pointer-events-none grid min-h-11 items-stretch bg-gradient-to-r from-blush-50/40 to-lilac-50/30 py-1.5 ring-1 ring-blush-100/80"
        style={{
          gridTemplateColumns: gridTemplate,
        }}
      >
        {lane.segments.map((seg) => (
          <DoseBand
            key={`${seg.fromDay}-${seg.toDay}-${seg.doseLabel}`}
            segment={seg}
            color={color}
          />
        ))}
      </div>
      {/* Taken fill (med color) + day pick — min height ~44px for touch */}
      <div
        className="absolute inset-0 z-10 grid py-1.5"
        style={{
          gridTemplateColumns: gridTemplate,
        }}
      >
        {columns.map((col) => {
          const cell = byDay.get(col.cycleDay)
          const taken = Boolean(cell && dayIsTaken(cell))
          return (
            <button
              key={col.cycleDay}
              type="button"
              disabled={!col.dateKey}
              onClick={() => onSelectDay(col)}
              title={
                cell
                  ? `${t('diagram.dayN', { day: col.cycleDay })}: ${cell.doseLabel}${
                      taken
                        ? ` · ${t('diagram.taken')}`
                        : ` · ${t('diagram.notTaken')}`
                    }`
                  : col.dateKey
                    ? `${t('diagram.dayN', { day: col.cycleDay })} · ${col.dateKey}`
                    : t('diagram.dayN', { day: col.cycleDay })
              }
              className={`min-h-0 px-px ${
                !col.dateKey ? 'cursor-default' : 'cursor-pointer'
              }`}
            >
              <span
                className="block h-full min-h-11 w-full rounded-md transition hover:bg-blush-300/10"
                style={taken ? { background: takenFill } : undefined}
              />
            </button>
          )
        })}
      </div>
    </div>
  )
}

/**
 * Dose segment card. Dose + day meta is position:sticky so it stays visible
 * while the day grid scrolls horizontally (pinned just right of med labels).
 */
function DoseBand({
  segment,
  color,
}: {
  segment: DoseSegment
  color: string
}) {
  const { t } = useLocale()
  const span = segment.toDay - segment.fromDay + 1
  const narrow = span === 1

  const dayLine =
    segment.fromDay === segment.toDay
      ? t('diagram.dayN', { day: segment.fromDay })
      : t('diagram.daysRange', {
          from: segment.fromDay,
          to: segment.toDay,
        })

  const meta = `${segment.doseLabel} · ${dayLine}`

  return (
    <div
      title={meta}
      className="relative box-border flex min-h-11 min-w-0 flex-col justify-center overflow-visible rounded-md text-left"
      style={{
        gridColumn: `${segment.fromDay} / span ${span}`,
        margin: '0 1.5px',
        maxWidth: '100%',
        background: '#fffafb',
        border: `1px solid ${color}55`,
        boxShadow: '0 1px 2px rgba(61, 44, 51, 0.04)',
      }}
    >
      {narrow ? (
        <span className="sr-only">{meta}</span>
      ) : (
        <div
          className="sticky z-[25] box-border rounded px-1.5 py-0.5 backdrop-blur-[1px]"
          style={{
            left: CYCLE_DOSE_META_STICKY_LEFT_PX,
            maxWidth: CYCLE_DOSE_META_MAX_WIDTH_PX,
            // Semi-transparent so band color shows through behind the label
            background: 'color-mix(in srgb, #fffafb 55%, transparent)',
            borderLeft: `2px solid ${color}`,
          }}
        >
          <p className="truncate text-[11px] font-bold leading-snug text-[#3d2c33]">
            {segment.doseLabel}
          </p>
          <p className="truncate text-[10px] font-medium leading-tight text-[#6b5560]">
            {dayLine}
          </p>
        </div>
      )}
    </div>
  )
}
