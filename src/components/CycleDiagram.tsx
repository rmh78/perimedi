import { useMemo } from 'react'
import { addDays, format, parseISO } from 'date-fns'
import type {
  CycleSettings,
  DayCycleInfo,
  Period,
  PlannedDose,
  Remark,
} from '../types'
import { getDayCycleInfo, lastPeriodStart } from '../lib/cycle'
import { toDateKey } from '../lib/dates'
import { buildMedLanes, type DoseSegment, type MedLane } from '../lib/medSegments'
import { MedFormIcon, MED_FORM_ICON_COLOR } from './MedFormIcon'
import { DoseCard } from './DoseCard'

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

type DayStatus = 'taken' | 'skipped' | 'open' | 'mixed' | null

const STATUS_STYLE: Record<
  Exclude<DayStatus, null>,
  { fill: string; ring: string; label: string }
> = {
  taken: { fill: '#059669', ring: '#a7f3d0', label: 'Taken' },
  skipped: { fill: '#d97706', ring: '#fde68a', label: 'Skipped' },
  open: { fill: '#94a3b8', ring: '#e2e8f0', label: 'Open' },
  mixed: { fill: '#9b6fc9', ring: '#e9d5ff', label: 'Mixed' },
}

function isSymptomRemark(r: Remark): boolean {
  return r.kind === 'cycle' || r.kind === 'side_effect' || r.kind === 'note'
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
  const cycleLen = Math.max(
    settings.averagePeriodLength + 2,
    settings.averageCycleLength,
  )
  const cycleStart = lastPeriodStart(periods)

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
    columns.find((c) => c.dateKey === selectedDate) ??
    columns.find((c) => c.isToday) ??
    columns[0]

  const selectedDay = selectedCol?.cycleDay ?? 1

  const selectedDayDoses = useMemo(() => {
    if (!selectedCol?.dateKey) return [] as PlannedDose[]
    return doses
      .filter((d) => d.date === selectedCol.dateKey)
      .sort((a, b) => a.timeOfDay.localeCompare(b.timeOfDay))
  }, [doses, selectedCol])

  const selectedSymptoms = selectedCol?.symptoms ?? []

  const laneStatuses = useMemo(() => {
    return lanes.map((lane) => {
      const statuses = selectedDayDoses
        .filter((d) => d.medication.id === lane.medicationId)
        .map((d) => d.status)
      return {
        medicationId: lane.medicationId,
        status: summarizeStatuses(statuses),
      }
    })
  }, [lanes, selectedDayDoses])

  const labelColPct = 18
  const plotPct = 100 - labelColPct
  const dayColLeft = (day: number) => ((day - 1) / cycleLen) * 100
  const dayColWidth = 100 / cycleLen
  const dayCenterPct = (day: number) => ((day - 0.5) / cycleLen) * 100

  function selectDay(col: DayColumn) {
    if (col.dateKey) onSelectDate(col.dateKey)
  }

  return (
    <section className="glass-card overflow-hidden rounded-[1.75rem]">
      <div className="border-b border-blush-100/80 px-5 py-4">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h3 className="section-title text-[1.45rem]">Meds & cycle</h3>
            <p className="mt-0.5 text-sm text-ink-soft">
              Select a day, mark doses, tap a med name to edit
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <button
              type="button"
              className="btn-primary !px-4 !py-1.5 text-xs"
              onClick={() => {
                const todayCol = columns.find((c) => c.isToday)
                if (todayCol?.dateKey) onSelectDate(todayCol.dateKey)
                else onSelectDate(today)
              }}
            >
              Today
            </button>
            <p className="rounded-full bg-blush-50 px-3 py-1 text-[11px] font-semibold uppercase tracking-wide text-blush-800 ring-1 ring-blush-100">
              {cycleStart
                ? `Since ${format(parseISO(cycleStart), 'MMM d')}`
                : 'Log period to align days'}
            </p>
          </div>
        </div>
      </div>

      <div className="space-y-1 px-3 py-4 sm:px-5">
        <div className="mb-1 flex flex-wrap items-center justify-between gap-2 px-1">
          <div className="flex flex-wrap items-center gap-x-4 gap-y-1">
            <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-ink-muted">
              Medications & doses
            </p>
            <div className="flex flex-wrap gap-3 text-[10px] text-ink-muted">
              <LegendDot className="bg-emerald-500" label="Taken" />
              <LegendDot className="bg-amber-500" label="Skipped" />
              <LegendDot className="bg-slate-400" label="Open" />
              <LegendDot className="bg-rose-500" label="Period" />
              <LegendDot className="bg-violet-400" label="Symptom" />
            </div>
          </div>
          {onAddMedication && (
            <button
              type="button"
              className="btn-primary !px-3 !py-1.5 text-xs"
              onClick={onAddMedication}
            >
              + Med
            </button>
          )}
        </div>

        {!cycleStart && (
          <p className="mb-3 rounded-2xl bg-lilac-50/80 px-3 py-2 text-sm text-ink-soft ring-1 ring-lilac-100">
            Tap <strong>Start period</strong> above so meds and symptoms line up with
            cycle days.
          </p>
        )}

        {/* One row per med so label + blocks share the same vertical center */}
        <div className="mb-2 flex items-start">
          <div
            style={{ width: `${labelColPct}%` }}
            className="h-9 shrink-0 pr-2"
            aria-hidden
          />
          <div className="relative h-9 min-w-0 flex-1">
            <div
              className="pointer-events-none absolute top-0 z-40 -translate-x-1/2 transition-all duration-200"
              style={{ left: `${dayCenterPct(selectedDay)}%` }}
            >
              <div className="flex flex-col items-center">
                <span className="whitespace-nowrap rounded-full bg-blush-600 px-2.5 py-1 text-[11px] font-bold text-white shadow-md">
                  Day {selectedDay}
                  {selectedCol?.dateKey
                    ? ` · ${format(parseISO(selectedCol.dateKey), 'MMM d')}`
                    : ''}
                </span>
                <span className="mt-0.5 h-2 w-0.5 bg-blush-500" />
              </div>
            </div>
          </div>
        </div>

        <div className="relative">
          {/* Selection guide + day pickers only over the plot column */}
          <div
            className="pointer-events-none absolute bottom-0 top-0 z-[5] rounded-sm bg-blush-400/12 transition-all duration-200"
            style={{
              left: `${labelColPct + (dayColLeft(selectedDay) * plotPct) / 100}%`,
              width: `${(dayColWidth * plotPct) / 100}%`,
            }}
            aria-hidden
          />
          <div
            className="pointer-events-none absolute bottom-0 top-0 z-20 transition-all duration-200"
            style={{
              left: `${labelColPct + (dayCenterPct(selectedDay) * plotPct) / 100}%`,
            }}
            aria-hidden
          >
            <div className="absolute inset-y-0 left-1/2 w-[2px] -translate-x-1/2 bg-gradient-to-b from-blush-500 via-blush-400 to-lilac-400 shadow-[0_0_8px_rgba(232,90,132,0.4)]" />
            <div className="absolute -bottom-0.5 left-1/2 h-2.5 w-2.5 -translate-x-1/2 rounded-full bg-blush-600 ring-2 ring-white shadow" />
          </div>
          <div
            className="absolute bottom-0 top-0 z-30"
            style={{ left: `${labelColPct}%`, width: `${plotPct}%` }}
          >
            <div
              className="grid h-full"
              style={{
                gridTemplateColumns: `repeat(${cycleLen}, minmax(0, 1fr))`,
              }}
            >
              {columns.map((col) => (
                <button
                  key={col.cycleDay}
                  type="button"
                  title={
                    col.dateKey
                      ? `Day ${col.cycleDay} · ${col.dateKey}${
                          col.isLoggedPeriod ? ' · period' : ''
                        }${
                          col.symptoms.length
                            ? ` · ${col.symptoms.length} symptom(s)`
                            : ''
                        }`
                      : `Day ${col.cycleDay}`
                  }
                  disabled={!col.dateKey}
                  onClick={() => selectDay(col)}
                  className={`h-full min-h-full border-r border-blush-100/30 transition last:border-r-0 ${
                    col.isSelected
                      ? 'bg-blush-500/5'
                      : 'hover:bg-blush-300/10'
                  } ${!col.dateKey ? 'cursor-default' : 'cursor-pointer'}`}
                />
              ))}
            </div>
          </div>

          <div className="relative z-10 space-y-2.5">
            {lanes.length === 0 && (
              <div className="flex items-center rounded-2xl bg-blush-50/50 px-3 py-4 ring-1 ring-blush-100">
                <div
                  style={{ width: `${labelColPct}%` }}
                  className="shrink-0 pr-2 text-sm text-ink-soft"
                >
                  No medications yet
                </div>
                <div className="min-w-0 flex-1 text-sm text-ink-muted">
                  Use <strong className="text-blush-800">+ Med</strong> to add one
                </div>
              </div>
            )}

            {lanes.map((lane) => {
              const status =
                laneStatuses.find((s) => s.medicationId === lane.medicationId)
                  ?.status ?? null
              return (
                <div
                  key={lane.medicationId}
                  className="flex items-center"
                >
                  <div
                    style={{ width: `${labelColPct}%` }}
                    className="shrink-0 pr-2"
                  >
                    <MedLaneLabel
                      lane={lane}
                      status={status}
                      onEdit={
                        onEditMedication
                          ? () => onEditMedication(lane.medicationId)
                          : undefined
                      }
                    />
                  </div>
                  <div className="min-w-0 flex-1 pointer-events-none">
                    <MedLaneTrack
                      lane={lane}
                      cycleLen={cycleLen}
                      selectedDay={selectedDay}
                    />
                  </div>
                </div>
              )
            })}

            <div className="flex items-stretch">
              <div
                style={{ width: `${labelColPct}%` }}
                className="flex shrink-0 flex-col justify-center pr-2"
              >
                <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-muted">
                  Cycle days
                </p>
                <p className="text-[10px] text-ink-muted">Period · symptoms</p>
              </div>
              <div className="min-w-0 flex-1 pointer-events-none">
                <CycleDayStrip
                  columns={columns}
                  cycleLen={cycleLen}
                  selectedDay={selectedDay}
                />
              </div>
            </div>
          </div>
        </div>

        {selectedCol && (
          <div className="relative z-40 mt-4 rounded-2xl border border-blush-200/80 bg-gradient-to-br from-blush-50/90 to-white px-4 py-4 shadow-sm">
            <div className="mb-3 flex flex-wrap items-start justify-between gap-3">
              <div className="min-w-0 flex-1">
                <p className="text-sm font-semibold text-ink">
                  Day {selectedCol.cycleDay}
                  {selectedCol.dateKey
                    ? ` · ${format(parseISO(selectedCol.dateKey), 'EEE, MMM d')}`
                    : ''}
                </p>
                <div className="mt-2 flex flex-wrap items-start gap-2">
                  {/* Period chip */}
                  {selectedCol.isLoggedPeriod ? (
                    <span className="inline-flex items-center gap-1.5 rounded-full bg-rose-100 px-2.5 py-1 text-xs font-semibold text-rose-800 ring-1 ring-rose-200">
                      <span className="h-2 w-2 rounded-full bg-rose-500" />
                      Period
                    </span>
                  ) : selectedCol.info?.isPredictedPeriod ? (
                    <span className="inline-flex items-center gap-1.5 rounded-full bg-rose-50 px-2.5 py-1 text-xs font-semibold text-rose-700 ring-1 ring-rose-100">
                      <span className="h-2 w-2 rounded-full bg-rose-300" />
                      Predicted period
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1.5 rounded-full bg-slate-50 px-2.5 py-1 text-xs font-medium text-ink-muted ring-1 ring-slate-100">
                      No period
                    </span>
                  )}

                  {/* Symptoms next to period info */}
                  {selectedSymptoms.length > 0 ? (
                    selectedSymptoms.map((s) => (
                      <span
                        key={s.id}
                        className="inline-flex max-w-full items-center gap-1.5 rounded-full bg-violet-50 px-2.5 py-1 text-xs font-medium text-violet-900 ring-1 ring-violet-100"
                        title={s.body}
                      >
                        <span className="h-2 w-2 shrink-0 rounded-full bg-violet-400" />
                        <span className="truncate">
                          <span className="font-semibold capitalize text-violet-700">
                            {s.kind.replace('_', ' ')}
                          </span>
                          {': '}
                          {s.body}
                        </span>
                      </span>
                    ))
                  ) : (
                    <span className="inline-flex items-center gap-1.5 rounded-full bg-slate-50 px-2.5 py-1 text-xs font-medium text-ink-muted ring-1 ring-slate-100">
                      No symptoms logged
                    </span>
                  )}
                </div>
                <div className="mt-2 flex flex-wrap items-center gap-2">
                  {onAddSymptom && selectedCol.dateKey && (
                    <button
                      type="button"
                      className="btn-soft !px-3 !py-1 text-xs"
                      onClick={() => onAddSymptom(selectedCol.dateKey!)}
                    >
                      + Symptom
                    </button>
                  )}
                  </div>
              </div>
            </div>

            {selectedDayDoses.length === 0 ? (
              <p className="text-sm text-ink-muted">
                No doses on this day.
              </p>
            ) : (
              <div className="space-y-2.5">
                {selectedDayDoses.map((d) => (
                  <DoseCard key={d.key} dose={d} compact />
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </section>
  )
}

function CycleDayStrip({
  columns,
  cycleLen,
  selectedDay,
}: {
  columns: DayColumn[]
  cycleLen: number
  selectedDay: number
}) {
  return (
    <div className="overflow-hidden rounded-2xl bg-white/80 ring-1 ring-blush-100">
      <div
        className="grid"
        style={{
          gridTemplateColumns: `repeat(${cycleLen}, minmax(0, 1fr))`,
        }}
      >
        {columns.map((col) => {
          const active = col.cycleDay === selectedDay
          return (
            <div
              key={col.cycleDay}
              className={`flex min-h-[4.5rem] flex-col items-center justify-end gap-1 border-r border-blush-50 px-0.5 py-2 last:border-r-0 ${
                col.isLoggedPeriod
                  ? 'bg-rose-100/80'
                  : col.info?.isPredictedPeriod
                    ? 'bg-rose-50/70'
                    : ''
              } ${active ? 'ring-2 ring-inset ring-blush-400' : ''}`}
            >
              {/* Symptom marks */}
              <div className="flex min-h-[12px] flex-col items-center gap-0.5">
                {col.symptoms.slice(0, 3).map((s) => (
                  <span
                    key={s.id}
                    className="h-1.5 w-1.5 rounded-full bg-violet-400"
                    title={s.body}
                  />
                ))}
                {col.symptoms.length > 3 && (
                  <span className="text-[8px] font-bold text-violet-600">
                    +{col.symptoms.length - 3}
                  </span>
                )}
              </div>

              <span
                className={`text-[10px] font-semibold ${
                  active
                    ? 'text-blush-700'
                    : col.isToday
                      ? 'text-blush-600'
                      : col.isLoggedPeriod
                        ? 'text-rose-800'
                        : 'text-ink-muted'
                }`}
                title={
                  col.isLoggedPeriod
                    ? `Day ${col.cycleDay}: period`
                    : col.info?.isPredictedPeriod
                      ? `Day ${col.cycleDay}: predicted period`
                      : `Day ${col.cycleDay}`
                }
              >
                {col.cycleDay}
              </span>
            </div>
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

function summarizeStatuses(
  statuses: Array<'pending' | 'taken' | 'skipped'>,
): DayStatus {
  if (statuses.length === 0) return null
  const allTaken = statuses.every((s) => s === 'taken')
  const allSkipped = statuses.every((s) => s === 'skipped')
  const allOpen = statuses.every((s) => s === 'pending')
  if (allTaken) return 'taken'
  if (allSkipped) return 'skipped'
  if (allOpen) return 'open'
  return 'mixed'
}

function MedLaneLabel({
  lane,
  status,
  onEdit,
}: {
  lane: MedLane
  status: DayStatus
  onEdit?: () => void
}) {
  const color = MED_FORM_ICON_COLOR[lane.form]
  const statusStyle = status ? STATUS_STYLE[status] : null
  const title = onEdit
    ? `Edit ${lane.name}`
    : statusStyle
      ? `${lane.name}: ${statusStyle.label} (selected day)`
      : `${lane.name}: not scheduled on selected day`

  const inner = (
    <>
      <span
        className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-white transition-all duration-200"
        style={{
          color,
          boxShadow: statusStyle
            ? `0 0 0 3px ${statusStyle.fill}`
            : '0 0 0 1px #f0d0da',
        }}
      >
        <MedFormIcon form={lane.form} size="md" />
      </span>
      <div className="min-w-0 text-left">
        <p className="truncate text-sm font-semibold leading-tight text-ink underline-offset-2 group-hover:underline">
          {lane.name}
        </p>
        <p className="truncate text-[10px] leading-tight text-ink-muted">
          {statusStyle ? (
            <span style={{ color: statusStyle.fill, fontWeight: 600 }}>
              {statusStyle.label}
            </span>
          ) : (
            'No dose today'
          )}
        </p>
      </div>
    </>
  )

  if (onEdit) {
    return (
      <button
        type="button"
        className="group flex w-full items-center gap-2 py-0.5"
        title={title}
        onClick={onEdit}
      >
        {inner}
      </button>
    )
  }

  return (
    <div className="flex items-center gap-2 py-0.5" title={title}>
      {inner}
    </div>
  )
}

function MedLaneTrack({
  lane,
  cycleLen,
  selectedDay,
}: {
  lane: MedLane
  cycleLen: number
  selectedDay: number
}) {
  const color = MED_FORM_ICON_COLOR[lane.form]
  const singleDaySegs = lane.segments.filter((s) => s.fromDay === s.toDay)
  const multiDaySegs = lane.segments.filter((s) => s.fromDay !== s.toDay)
  const useSparseMarkers =
    singleDaySegs.length >= 3 &&
    multiDaySegs.length === 0 &&
    new Set(singleDaySegs.map((s) => s.doseLabel)).size === 1

  if (useSparseMarkers) {
    return (
      <SparseDoseTrack
        cycleLen={cycleLen}
        selectedDay={selectedDay}
        color={color}
        doseLabel={singleDaySegs[0].doseLabel}
        days={singleDaySegs.map((s) => s.fromDay)}
      />
    )
  }

  return (
    <div
      className="grid min-h-[3.25rem] items-stretch rounded-2xl bg-gradient-to-r from-blush-50/40 to-lilac-50/30 py-1.5 ring-1 ring-blush-100/80"
      style={{
        gridTemplateColumns: `repeat(${cycleLen}, minmax(0, 1fr))`,
      }}
    >
      {lane.segments.map((seg) => (
        <DoseBand
          key={`${seg.fromDay}-${seg.toDay}-${seg.doseLabel}`}
          segment={seg}
          color={color}
          selectedDay={selectedDay}
        />
      ))}
    </div>
  )
}

function SparseDoseTrack({
  cycleLen,
  selectedDay,
  color,
  doseLabel,
  days,
}: {
  cycleLen: number
  selectedDay: number
  color: string
  doseLabel: string
  days: number[]
}) {
  const daySet = new Set(days)
  const dayList = [...days].sort((a, b) => a - b)
  const countLabel = `${dayList.length}× this cycle`

  return (
    <div
      className="overflow-hidden rounded-2xl ring-1"
      style={{
        borderColor: `${color}44`,
        background: '#fffafb',
        boxShadow: `inset 3px 0 0 ${color}`,
      }}
      title={`${doseLabel} on days ${dayList.join(', ')}`}
    >
      <div className="flex items-baseline justify-between gap-2 border-b border-blush-100/80 px-2.5 py-1.5">
        <span className="min-w-0 truncate text-[12px] font-bold leading-tight text-[#3d2c33]">
          {doseLabel}
        </span>
        <span className="shrink-0 text-[10px] font-medium text-[#6b5560]">
          {countLabel}
        </span>
      </div>
      <div
        className="grid items-center px-0.5 py-2"
        style={{
          gridTemplateColumns: `repeat(${cycleLen}, minmax(0, 1fr))`,
        }}
      >
        {Array.from({ length: cycleLen }, (_, i) => {
          const day = i + 1
          const on = daySet.has(day)
          const active = day === selectedDay
          return (
            <div key={day} className="flex min-w-0 items-center justify-center">
              {on ? (
                <span
                  className="block h-6 w-[65%] max-w-[12px] rounded-full transition"
                  style={{
                    background: active ? color : `${color}bb`,
                    boxShadow: active
                      ? `0 0 0 2px #fff, 0 0 0 3.5px ${color}`
                      : undefined,
                  }}
                />
              ) : (
                <span className="block h-1 w-1 rounded-full bg-blush-100" />
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}

function DoseBand({
  segment,
  color,
  selectedDay,
}: {
  segment: DoseSegment
  color: string
  selectedDay: number
}) {
  const span = segment.toDay - segment.fromDay + 1
  const active =
    selectedDay >= segment.fromDay && selectedDay <= segment.toDay
  const roomy = span >= 4
  const medium = span === 2 || span === 3
  const narrow = span === 1

  const dayLine =
    segment.fromDay === segment.toDay
      ? `Day ${segment.fromDay}`
      : `Days ${segment.fromDay}–${segment.toDay}`

  return (
    <div
      title={`${dayLine}: ${segment.doseLabel}`}
      className="box-border flex min-h-[2.5rem] min-w-0 flex-col items-stretch justify-center overflow-hidden rounded-md text-left transition"
      style={{
        gridColumn: `${segment.fromDay} / span ${span}`,
        margin: '0 1.5px',
        maxWidth: '100%',
        padding: roomy ? '6px 8px' : medium ? '5px 6px' : '0',
        background: narrow
          ? active
            ? color
            : `${color}dd`
          : active
            ? `linear-gradient(90deg, ${color} 0 3px, #ffffff 3px, #fffafb 100%)`
            : `linear-gradient(90deg, ${color} 0 3px, #ffffff 3px, #fff9fb 100%)`,
        border: narrow
          ? `1px solid ${color}`
          : `1px solid ${active ? color : '#e8c9d4'}`,
        boxShadow: active
          ? narrow
            ? `0 0 0 2px #fff, 0 0 0 3px ${color}`
            : `0 0 0 1px ${color}33, 0 1px 2px rgba(61, 44, 51, 0.06)`
          : '0 1px 2px rgba(61, 44, 51, 0.04)',
      }}
    >
      {narrow ? (
        <span className="sr-only">
          {dayLine}: {segment.doseLabel}
        </span>
      ) : (
        <>
          <span
            className={`w-full truncate font-bold leading-snug text-[#3d2c33] ${
              roomy ? 'text-[12px]' : 'text-[11px]'
            }`}
          >
            {segment.doseLabel}
          </span>
          <span className="mt-0.5 w-full truncate text-[10px] font-medium leading-tight text-[#6b5560]">
            {dayLine}
          </span>
        </>
      )}
    </div>
  )
}
