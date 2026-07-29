import { useMemo, useState } from 'react'
import { addDays, format, parseISO } from 'date-fns'
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
import { setDoseStatus } from '../db/actions'
import { PeriodSettingsSheet } from './PeriodSettingsSheet'
import { BloodDropIcon, SymptomMarkIcon } from './CycleMarks'
import { iconBgFromColor, takenFillFromColor } from '../lib/medColors'

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

function isSymptomRemark(r: Remark): boolean {
  return r.kind === 'cycle' || r.kind === 'side_effect' || r.kind === 'note'
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
  const [periodSettingsOpen, setPeriodSettingsOpen] = useState(false)

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

  const labelColPct = 22
  const plotPct = 100 - labelColPct
  const dayColLeft = (day: number) => ((day - 1) / cycleLen) * 100
  const dayColWidth = 100 / cycleLen
  const dayCenterPct = (day: number) => ((day - 0.5) / cycleLen) * 100

  function selectDay(col: DayColumn) {
    if (col.dateKey) onSelectDate(col.dateKey)
  }

  return (
    <>
    <section className="glass-card overflow-hidden rounded-[1.75rem]">
      <div className="border-b border-blush-100/80 px-5 py-4">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h3 className="section-title text-[1.45rem]">Meds & cycle</h3>
            <p className="mt-0.5 text-sm text-ink-soft">
              Select a day · tap med icon to mark taken · tap name to edit
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
        <div className="mb-1 flex flex-wrap items-center gap-x-4 gap-y-1 px-1">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-ink-muted">
            Medications & doses
          </p>
          <div className="flex flex-wrap gap-3 text-[10px] text-ink-muted">
            <LegendDot className="bg-emerald-500" label="Taken" />
            <LegendDot className="bg-slate-400" label="Not taken" />
            <span className="inline-flex items-center gap-1">
              <BloodDropIcon />
              Period
            </span>
            <span className="inline-flex items-center gap-1">
              <SymptomMarkIcon />
              Symptom
            </span>
          </div>
        </div>

        {!cycleStart && (
          <p className="mb-3 rounded-2xl bg-lilac-50/80 px-3 py-2 text-sm text-ink-soft ring-1 ring-lilac-100">
            Tap <strong>Start period</strong> above so meds and symptoms line up with
            cycle days.
          </p>
        )}

        {/* Plot + day label + selection overlay share one stack so the gray
            column meets the badge with no gap or stem. */}
        <div className="relative pt-8">
          <div
            className="pointer-events-none absolute left-0 right-0 top-0 z-40 flex"
            aria-hidden
          >
            <div
              style={{ width: `${labelColPct}%` }}
              className="shrink-0 pr-2"
            />
            <div className="relative min-w-0 flex-1">
              <div
                className="absolute top-0 -translate-x-1/2 transition-all duration-200"
                style={{ left: `${dayCenterPct(selectedDay)}%` }}
              >
                <span className="whitespace-nowrap rounded-full bg-blush-600 px-2.5 py-1 text-[11px] font-bold text-white shadow-md">
                  Day {selectedDay}
                  {selectedCol?.dateKey
                    ? ` · ${format(parseISO(selectedCol.dateKey), 'MMM d')}`
                    : ''}
                </span>
              </div>
            </div>
          </div>

          <div className="relative z-10 space-y-3">
            {lanes.length === 0 && (
              <div className="relative z-40 flex flex-col items-center justify-center gap-3 rounded-2xl border border-dashed border-blush-200 bg-white/70 px-6 py-10 text-center shadow-sm">
                <div className="flex h-12 w-12 items-center justify-center rounded-full bg-blush-50 ring-1 ring-blush-100">
                  <span className="text-xl text-blush-500" aria-hidden>
                    +
                  </span>
                </div>
                <div className="space-y-1">
                  <p className="text-base font-semibold text-ink">
                    No medications yet
                  </p>
                  <p className="max-w-xs text-sm text-ink-muted">
                    Add a medication to plan doses along your cycle and mark them
                    as taken.
                  </p>
                </div>
                {onAddMedication && (
                  <button
                    type="button"
                    className="btn-primary !px-5 !py-2 text-sm"
                    onClick={onAddMedication}
                  >
                    + Add medication
                  </button>
                )}
              </div>
            )}

            {lanes.map((lane) => {
              const dayDoses = selectedDayDoses.filter(
                (d) => d.medication.id === lane.medicationId,
              )
              return (
                <div
                  key={lane.medicationId}
                  className="flex items-center gap-0"
                >
                  <div
                    style={{ width: `${labelColPct}%` }}
                    className="relative z-40 flex shrink-0 items-center pr-2"
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
                  <div className="relative z-10 min-w-0 flex-1">
                    <MedLaneTrack
                      lane={lane}
                      cycleLen={cycleLen}
                      selectedDay={selectedDay}
                      columns={columns}
                      onSelectDay={selectDay}
                    />
                  </div>
                </div>
              )
            })}

            <div className="flex items-stretch">
              <div
                style={{ width: `${labelColPct}%` }}
                className="relative z-40 flex shrink-0 flex-col justify-center pr-2"
              >
                <p className="text-[10px] font-semibold uppercase tracking-wide text-ink-muted">
                  Cycle days
                </p>
                <p className="mt-0.5 text-[10px] text-ink-muted">
                  {settings.averageCycleLength}d ·{' '}
                  {settings.averagePeriodLength}d period
                </p>
              </div>
              <div className="relative z-10 min-w-0 flex-1">
                <CycleDayStrip
                  columns={columns}
                  cycleLen={cycleLen}
                  selectedDay={selectedDay}
                  onSelectDay={selectDay}
                />
              </div>
            </div>
          </div>
          {/* Overlay from under day badge through meds + cycle strip */}
          <div
            className="pointer-events-none absolute bottom-0 z-30 transition-all duration-200"
            style={{
              top: '1.75rem',
              left: `${labelColPct + (dayColLeft(selectedDay) * plotPct) / 100}%`,
              width: `${(dayColWidth * plotPct) / 100}%`,
              background: 'rgba(15, 23, 42, 0.14)',
            }}
            aria-hidden
          />
        </div>

        {selectedCol && (
          <div className="relative z-40 mt-4 rounded-2xl border border-blush-200/80 bg-gradient-to-br from-blush-50/90 to-white px-4 py-4 shadow-sm">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div className="min-w-0 flex-1">
                <p className="text-sm font-semibold text-ink">
                  Day {selectedCol.cycleDay}
                  {selectedCol.dateKey
                    ? ` · ${format(parseISO(selectedCol.dateKey), 'EEE, MMM d')}`
                    : ''}
                </p>
                <div className="mt-2 flex flex-wrap items-start gap-2">
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
              </div>
            </div>
            <div className="mt-3 flex flex-wrap gap-2">
              {onAddMedication && (
                <button
                  type="button"
                  className="btn-primary !px-3 !py-1.5 text-xs"
                  onClick={onAddMedication}
                >
                  + Med
                </button>
              )}
              <button
                type="button"
                className="btn-ghost !px-3 !py-1.5 text-xs"
                onClick={() => setPeriodSettingsOpen(true)}
              >
                Cycle settings
              </button>
              {onAddSymptom && selectedCol.dateKey && (
                <button
                  type="button"
                  className="btn-soft !px-3 !py-1.5 text-xs"
                  onClick={() => onAddSymptom(selectedCol.dateKey!)}
                >
                  + Symptom
                </button>
              )}
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
  cycleLen,
  selectedDay,
  onSelectDay,
}: {
  columns: DayColumn[]
  cycleLen: number
  selectedDay: number
  onSelectDay: (col: DayColumn) => void
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
            <button
              key={col.cycleDay}
              type="button"
              disabled={!col.dateKey}
              onClick={() => onSelectDay(col)}
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
              className={`flex min-h-[4.75rem] flex-col items-center justify-end gap-0.5 border-r border-blush-50 px-0.5 py-2 transition last:border-r-0 ${
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
              <div className="flex h-3.5 w-full items-center justify-center">
                {(col.isLoggedPeriod || col.info?.isPredictedPeriod) && (
                  <BloodDropIcon
                    predicted={
                      !col.isLoggedPeriod &&
                      Boolean(col.info?.isPredictedPeriod)
                    }
                    title={
                      col.isLoggedPeriod ? 'Period' : 'Predicted period'
                    }
                  />
                )}
              </div>
              {/* Row 2: symptom icons */}
              <div className="flex h-3.5 w-full items-center justify-center gap-px">
                {col.symptoms.slice(0, 3).map((s) => (
                  <SymptomMarkIcon
                    key={s.id}
                    kind={s.kind}
                    title={s.body}
                  />
                ))}
                {col.symptoms.length > 3 && (
                  <span className="text-[7px] font-bold leading-none text-violet-600">
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

function MedLaneLabel({
  lane,
  dayDoses,
  onEdit,
}: {
  lane: MedLane
  dayDoses: PlannedDose[]
  onEdit?: () => void
}) {
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
  const statusLabel = isTaken ? 'Taken' : hasDose ? 'Not taken' : 'No dose'
  const statusColor = isTaken ? color : hasDose ? '#64748b' : undefined

  return (
    <div className="flex w-full items-center gap-2 py-0.5">
      <button
        type="button"
        disabled={!hasDose}
        onClick={toggleTaken}
        title={
          hasDose
            ? isTaken
              ? `Mark ${lane.name} as not taken`
              : `Mark ${lane.name} as taken`
            : `${lane.name}: no dose on selected day`
        }
        aria-pressed={hasDose ? isTaken : undefined}
        aria-label={
          hasDose
            ? `${lane.name}: ${statusLabel}. Tap to toggle.`
            : `${lane.name}: no dose on selected day`
        }
        className={`relative h-12 w-12 shrink-0 rounded-full transition ${
          hasDose
            ? 'cursor-pointer hover:scale-105 active:scale-95'
            : 'cursor-default opacity-70'
        }`}
        style={{
          boxShadow: `0 0 0 4px ${ring}`,
          background: iconBgFromColor(color, 0.35),
        }}
      >
        {/* Clip only the image so the check badge can overlap the circle edge */}
        <span className="absolute inset-0 overflow-hidden rounded-full">
          <MedFormIcon form={lane.form} fill />
        </span>
        {isTaken && (
          <span
            className="absolute -bottom-1 -right-1 z-10 flex h-5 w-5 items-center justify-center rounded-full text-[10px] font-bold text-white ring-2 ring-white shadow-sm"
            style={{ background: color }}
            aria-hidden
          >
            ✓
          </span>
        )}
      </button>

      {onEdit ? (
        <button
          type="button"
          className="group min-w-0 flex-1 text-left"
          title={`Edit ${lane.name}`}
          onClick={onEdit}
        >
          <p className="truncate text-sm font-semibold leading-tight text-ink underline-offset-2 group-hover:underline">
            {lane.name}
          </p>
          <p
            className="truncate text-[10px] font-semibold leading-tight"
            style={{ color: statusColor ?? undefined }}
          >
            {statusLabel === 'No dose' ? (
              <span className="font-medium text-ink-muted">{statusLabel}</span>
            ) : (
              statusLabel
            )}
          </p>
        </button>
      ) : (
        <div className="min-w-0 flex-1 text-left">
          <p className="truncate text-sm font-semibold leading-tight text-ink">
            {lane.name}
          </p>
          <p
            className="truncate text-[10px] font-semibold leading-tight"
            style={{ color: statusColor ?? undefined }}
          >
            {statusLabel === 'No dose' ? (
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
  cycleLen,
  columns,
  onSelectDay,
}: {
  lane: MedLane
  cycleLen: number
  selectedDay: number
  columns: DayColumn[]
  onSelectDay: (col: DayColumn) => void
}) {
  const color = lane.color
  const byDay = new Map(lane.days.map((d) => [d.cycleDay, d]))
  const takenFill = takenFillFromColor(color, 0.42)

  return (
    <div className="relative">
      <div
        className="pointer-events-none grid min-h-[3.25rem] items-stretch bg-gradient-to-r from-blush-50/40 to-lilac-50/30 py-1.5 ring-1 ring-blush-100/80"
        style={{
          gridTemplateColumns: `repeat(${cycleLen}, minmax(0, 1fr))`,
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
      {/* Taken fill (med color) + day pick */}
      <div
        className="absolute inset-0 z-10 grid py-1.5"
        style={{
          gridTemplateColumns: `repeat(${cycleLen}, minmax(0, 1fr))`,
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
                  ? `Day ${col.cycleDay}: ${cell.doseLabel}${
                      taken ? ' · Taken' : ' · Not taken'
                    }`
                  : col.dateKey
                    ? `Day ${col.cycleDay} · ${col.dateKey}`
                    : `Day ${col.cycleDay}`
              }
              className={`min-h-0 px-[1.5px] ${
                !col.dateKey ? 'cursor-default' : 'cursor-pointer'
              }`}
            >
              <span
                className="block h-full min-h-[2.5rem] w-full rounded-md transition hover:bg-blush-300/10"
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
 * Dose segment card — same chrome for multi-day ranges and single-day doses.
 * Narrow days drop text; tooltips keep the full label.
 */
function DoseBand({
  segment,
  color,
}: {
  segment: DoseSegment
  color: string
}) {
  const span = segment.toDay - segment.fromDay + 1
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
      className="box-border flex min-h-[2.5rem] min-w-0 flex-col items-stretch justify-center overflow-hidden rounded-md text-left"
      style={{
        gridColumn: `${segment.fromDay} / span ${span}`,
        margin: '0 1.5px',
        maxWidth: '100%',
        padding: roomy ? '6px 8px' : medium ? '5px 6px' : '4px 2px',
        background: '#fffafb',
        border: `1px solid ${color}55`,
        boxShadow: '0 1px 2px rgba(61, 44, 51, 0.04)',
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
