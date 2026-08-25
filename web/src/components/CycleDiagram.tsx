import {
  useCallback,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from 'react'
import { addDays, parseISO } from 'date-fns'
import type { CycleSettings, Period, PlannedDose, Remark } from '../types'
import { cycleWindowForDate, getDayCycleInfo } from '../lib/cycle'
import { toDateKey } from '../lib/dates'
import { buildMedLanes } from '../lib/medSegments'
import { PeriodSettingsSheet } from './PeriodSettingsSheet'
import { BloodDropIcon, SymptomMarkIcon } from './CycleMarks'
import { useLocale } from '../i18n'
import { computeDayScrollLeft } from '../lib/chartScroll'
import {
  CYCLE_DAY_MIN_PX,
  CYCLE_LABEL_COL_PX,
  CYCLE_LABEL_PAD_LEFT_PX,
  selectedDayPlotLeftPct,
  selectedDayPlotWidthPct,
} from '../lib/cycleLayout'
import { CycleDayHeader } from './CycleDayHeader'
import { CycleDayStrip } from './CycleDayStrip'
import { MedLaneLabel, MedLaneTrack } from './CycleMedLanes'
import type { DayColumn } from './cycleTypes'

const ACTION_ICON = {
  med: '/action-icons/med.jpg',
  period: '/action-icons/period.jpg',
  symptom: '/action-icons/symptom.jpg',
} as const

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

const DAY_MIN_PX = CYCLE_DAY_MIN_PX
const LABEL_COL_PX = CYCLE_LABEL_COL_PX
const LABEL_PAD_LEFT_PX = CYCLE_LABEL_PAD_LEFT_PX

function isSymptomRemark(r: Remark): boolean {
  return r.kind === 'cycle' || r.kind === 'side_effect' || r.kind === 'note'
}

function dayGridTemplate(cycleLen: number): string {
  return `repeat(${cycleLen}, minmax(${DAY_MIN_PX}px, 1fr))`
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
  const { t } = useLocale()
  const [periodSettingsOpen, setPeriodSettingsOpen] = useState(false)
  const plotScrollRef = useRef<HTMLDivElement>(null)
  const [plotEdge, setPlotEdge] = useState({ left: false, right: false })
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

  const prevCycleStart = useRef(cycleStart)
  useLayoutEffect(() => {
    if (prevCycleStart.current === cycleStart) return
    prevCycleStart.current = cycleStart
    if (!didInitialScrollToSelected.current) return
    const col = columns.find((c) => c.dateKey === selectedDate)
    if (col) scrollDayIntoView(col.cycleDay, 'auto')
  }, [cycleStart, selectedDate, columns, scrollDayIntoView])

  function selectDay(col: DayColumn) {
    if (col.dateKey) onSelectDate(col.dateKey)
  }

  function goToToday() {
    const todayCol = columns.find((c) => c.isToday)
    const dateKey = todayCol?.dateKey ?? today
    onSelectDate(dateKey)
    setScrollToDate(dateKey)
  }

  useLayoutEffect(() => {
    const el = plotScrollRef.current
    if (!el) return
    const update = () => {
      const max = el.scrollWidth - el.clientWidth
      setPlotEdge({
        left: el.scrollLeft > 4,
        right: max > 4 && el.scrollLeft < max - 4,
      })
    }
    update()
    el.addEventListener('scroll', update, { passive: true })
    window.addEventListener('resize', update)
    return () => {
      el.removeEventListener('scroll', update)
      window.removeEventListener('resize', update)
    }
  }, [cycleLen, lanes.length, chartMinWidth])

  function pageDay(delta: -1 | 1) {
    const key = selectedCol?.dateKey ?? selectedDate
    if (!key) return
    const nextKey = toDateKey(addDays(parseISO(key), delta))
    onSelectDate(nextKey)
    setScrollToDate(nextKey)
  }

  const canPagePrev = true
  const canPageNext = true

  return (
    <>
    <div className="space-y-3">
    <section className="glass-card overflow-hidden rounded-2xl sm:rounded-[1.75rem]">
      <CycleDayHeader
        selectedCol={selectedCol}
        selectedSymptoms={selectedSymptoms}
        canPagePrev={canPagePrev}
        canPageNext={canPageNext}
        onPageDay={pageDay}
        onGoToToday={goToToday}
        onAddSymptom={onAddSymptom}
      />

      <div className="space-y-1 px-2 py-2.5 sm:px-5 sm:py-4">
        <div className="mb-1 flex items-center gap-2 px-1">
          <p className="min-w-0 flex-1 text-[11px] font-semibold uppercase tracking-[0.12em] text-ink-muted">
            {t('diagram.medsAndDoses')}
          </p>
          <div className="flex shrink-0 items-center gap-1.5">
            <DayActionIconButton
              label={t('diagram.cycleSettings')}
              onClick={() => setPeriodSettingsOpen(true)}
              src={ACTION_ICON.period}
            />
            {onAddMedication && (
              <DayActionIconButton
                label={t('diagram.addMed')}
                onClick={onAddMedication}
                src={ACTION_ICON.med}
                plus
              />
            )}
            {onAddSymptom && selectedCol?.dateKey && (
              <DayActionIconButton
                label={t('diagram.addSymptom')}
                onClick={() => onAddSymptom(selectedCol.dateKey!)}
                src={ACTION_ICON.symptom}
                plus
              />
            )}
          </div>
        </div>
        <div className="mb-1 flex flex-wrap gap-3 px-1 text-[11px] text-ink-muted">
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

        {lanes.length === 0 ? (
          <div className="rounded-2xl border border-dashed border-blush-200 bg-white/70 px-3 py-6 text-center sm:px-5">
            <p className="text-sm font-semibold text-ink">
              {t('diagram.emptyMedsTitle')}
            </p>
            <p className="mt-1 text-[12px] leading-snug text-ink-muted sm:text-sm">
              {t('diagram.emptyMedsBody')}
            </p>
          </div>
        ) : (
          /*
            Two-column scroll row: sticky identity (cycle meta + meds) + plot
            (day strip + dose bands). Selection highlight stays plot-only.
          */
          <div className="relative">
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
                  <p className="text-[11px] font-semibold uppercase tracking-wide text-ink-muted">
                    {t('diagram.cycleDays')}
                  </p>
                  {settings.tracksPeriods !== false && (
                    <p className="mt-0.5 text-[11px] text-ink-muted">
                      {t('diagram.cyclePeriodMeta', {
                        cycle: settings.averageCycleLength,
                        period: settings.averagePeriodLength,
                      })}
                    </p>
                  )}
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
                      background: 'rgba(232, 90, 132, 0.16)',
                    }}
                  />
                </div>
              </div>
            </div>
          </div>
          {plotEdge.left && (
            <div
              className="pointer-events-none absolute inset-y-0 z-20 w-6 bg-gradient-to-r from-cream to-transparent"
              style={{ left: LABEL_COL_PX }}
              aria-hidden
            />
          )}
          {plotEdge.right && (
            <div
              className="pointer-events-none absolute inset-y-0 right-0 z-20 w-8 bg-gradient-to-l from-cream to-transparent"
              aria-hidden
            />
          )}
          </div>
        )}
      </div>
    </section>

    {lanes.length === 0 && (
      <section className="glass-card rounded-2xl px-3 py-3.5 sm:rounded-[1.75rem] sm:px-5 sm:py-5">
        <p className="text-sm font-semibold text-ink">
          {t('diagram.emptyTitle')}
        </p>
        <p className="mt-1 text-[12px] leading-snug text-ink-muted sm:text-sm">
          {t('diagram.emptyBody')}
        </p>
        <ul className="mt-3 space-y-1.5">
          <li>
            <EmptyHintRow
              label={t('diagram.emptyAddPeriod')}
              onClick={() => setPeriodSettingsOpen(true)}
              src={ACTION_ICON.period}
            />
          </li>
          {onAddMedication && (
            <li>
              <EmptyHintRow
                label={t('diagram.emptyAddMed')}
                onClick={onAddMedication}
                src={ACTION_ICON.med}
                plus
              />
            </li>
          )}
          {onAddSymptom && selectedCol?.dateKey && (
            <li>
              <EmptyHintRow
                label={t('diagram.emptyAddSymptom')}
                onClick={() => onAddSymptom(selectedCol.dateKey!)}
                src={ACTION_ICON.symptom}
                plus
              />
            </li>
          )}
        </ul>
      </section>
    )}
    </div>
    <PeriodSettingsSheet
      open={periodSettingsOpen}
      onClose={() => setPeriodSettingsOpen(false)}
    />
    </>
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

function PlusBadge() {
  return (
    <span
      className="absolute -bottom-0.5 -right-0.5 z-10 flex h-4 w-4 items-center justify-center rounded-full bg-blush-600 text-[12px] font-bold leading-none text-white ring-2 ring-white shadow-sm"
      aria-hidden
    >
      +
    </span>
  )
}

function ActionGlyph({ src }: { src: string }) {
  return (
    <img
      src={src}
      alt=""
      className="h-full w-full object-cover"
      draggable={false}
    />
  )
}

function EmptyHintRow({
  label,
  onClick,
  src,
  plus,
}: {
  label: string
  onClick: () => void
  src: string
  plus?: boolean
}) {
  return (
    <button
      type="button"
      className="flex w-full items-center gap-2.5 rounded-xl px-1 py-1 text-left transition hover:bg-blush-50"
      onClick={onClick}
    >
      <span className="relative h-9 w-9 shrink-0">
        <span className="absolute inset-0 overflow-hidden rounded-full bg-blush-50 ring-1 ring-blush-100">
          <ActionGlyph src={src} />
        </span>
        {plus ? <PlusBadge /> : null}
      </span>
      <span className="min-w-0 text-[13px] font-medium leading-snug text-ink">
        {label}
      </span>
    </button>
  )
}

function DayActionIconButton({
  label,
  onClick,
  src,
  plus,
}: {
  label: string
  onClick: () => void
  src: string
  plus?: boolean
}) {
  return (
    <button
      type="button"
      className="relative h-9 w-9 shrink-0 overflow-visible rounded-full transition hover:scale-105 active:scale-95"
      aria-label={label}
      title={label}
      onClick={onClick}
    >
      <span className="absolute inset-0 overflow-hidden rounded-full bg-blush-50 ring-1 ring-blush-100">
        <ActionGlyph src={src} />
      </span>
      {plus ? <PlusBadge /> : null}
    </button>
  )
}
